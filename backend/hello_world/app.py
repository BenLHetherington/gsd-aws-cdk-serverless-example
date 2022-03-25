import json
import os
import logging
import boto3
from botocore.exceptions import ClientError
import pandas as pd
import openpyxl
import numpy as np

# Handle logger
logger = logging.getLogger()
logger.setLevel(logging.os.environ['LOG_LEVEL'])

dynamodb = boto3.resource('dynamodb')
aws_environment = os.environ['AWSENV']

logger.info("Finished handling variables, imports, and clients")

# Check if executing locally or on AWS, and configure DynamoDB connection accordingly.
# https://github.com/ganshan/sam-dynamodb-local/blob/master/src/Person.py
if aws_environment == "AWS_SAM_LOCAL":
    table = boto3.resource('dynamodb', endpoint_url="http://dynamodb-local:8000").Table('visitorCount') #Local table name hard coded in entrypoint.sh for local dev
    logger.info("Using local Dynamo container for testing")
else: # Running in AWS
    table = dynamodb.Table(os.environ['TABLE_NAME'])

logger.info("Finished conditional dynamodb logic")

def getUserCount():
    try:
        logger.info("Querying DDB")
        user_count_from_table = table.get_item(
            Key={'Count': 'Users'}
        )

        #Handle first use case where count doesn't exist yet
        if 'Item' in user_count_from_table:
            user_count = user_count_from_table['Item']['Number'] +1
        else: 
            user_count = 1
        logger.info(user_count)

        return user_count

    #Catch known errors
    #ToDo: Add more handling here
    except ClientError as e:
        if e.response['Error']['Code'] == 'RequestLimitExceeded':
            logger.error('ERROR: ', e)
        else:
            logger.error("UNEXPECTED ERROR from DDB: %s" % e)

def updateUserCount(count):
    try:
        logger.info("Updating DDB with new user count")
        table.put_item(
            Item={
                'Count': 'Users',
                'Number': count
            }
        )

    #Catch known errors
    #ToDo: Add more handling here
    except ClientError as e:
        if e.response['Error']['Code'] == 'RequestLimitExceeded':
            logger.error('ERROR: ', e)
        else:
            logger.error("UNEXPECTED ERROR from DDB: %s" % e)


def passiveGrowth(BEGdate, ENDdate, RID):
    
    #Reads Data In
    sarsales = pd.read_excel(r'data.xlsx', sheet_name='sarsales')
    #sarsalesColumns = sarsales.columns.tolist()
    sarsales=sarsales.to_numpy()
    ElastRSector = pd.read_excel(r'data.xlsx', sheet_name='Elasticites')
    ElastRSectorColumns = ElastRSector.columns.tolist()
    ElastRSector=ElastRSector.to_numpy()
    EFactors = pd.read_excel(r'data.xlsx', sheet_name='Econ Factors data')
    EFactors=EFactors.to_numpy()
    SizeSarsales = sarsales.shape[0]
    SizeEFactors = EFactors.shape[0]
    SizeElastRSector = ElastRSector.shape[0]
    WidthElastRSector = ElastRSector.shape[1]

    # logger.info(EFactors)
    logger.info("SizeSarsales: "+str(SizeSarsales))

    #Declares a few variables as set up
    TRBID = RID * 1000000 + BEGdate
    TREID = RID * 1000000 + ENDdate
    TotalEconomicFactor = 0
    factors = []

    # logger.info("SizeSarsales:",str(SizeSarsales))

    #Gets rsale for start and end
    RSaleBeg=0
    RSaleEnd=0
    i=0
    while i < SizeSarsales:
        if sarsales[i][2] == TRBID:
            RSaleBeg = sarsales[i][4]
        if sarsales[i][2] == TREID:
            RSaleEnd = sarsales[i][4]
        if ((RSaleBeg != 0) and (RSaleEnd != 0)):
            break
        i=i+1

    #Sets TGRSales
    TGRSales = (RSaleEnd - RSaleBeg)/RSaleBeg

    #Gets index of interest from EFactors
    i=0
    while i < SizeEFactors:
        if EFactors[i][0] == BEGdate:
            EFactorsIndex1 = i
        if EFactors[i][0] == ENDdate:
            EFactorsIndex2 = i
        i=i+1

    ##Finds none zero values in EfactorsIndex1 and EfactorsIndex2 and calculates factors
    ##----------assumes its sorted (ie column[x] is the same factor in EFactors and ElastRSector
    ##Generates index we care about from ElastRSector
    i = 0
    while i < SizeElastRSector:
        if ElastRSector[i][0] == RID:
            ElastRSectorIndex = i
            #finds none-zero values
            j=2
            while j < WidthElastRSector:
                if ElastRSector[i][j] != 0:
                    #None zero Column
                    factors.append(j)
                    #Factor Name
                    #factors.append(ElastRSector[0][j])
                    factors.append(ElastRSectorColumns[j])
                    temp1=ElastRSector[i][j]
                    #Elastisity
                    factors.append(ElastRSector[i][j])
                    temp2=((EFactors[EFactorsIndex2][j-1] - EFactors[EFactorsIndex1][j-1]) / EFactors[EFactorsIndex1][j-1])
                    #growth
                    factors.append((EFactors[EFactorsIndex2][j-1] - EFactors[EFactorsIndex1][j-1]) / EFactors[EFactorsIndex1][j-1])
                    #Impact
                    factors.append(temp1*temp2)
                    #Begining factor
                    factors.append(EFactors[EFactorsIndex1][j-1])
                    #Ending factor
                    factors.append(EFactors[EFactorsIndex2][j - 1])
                    TotalEconomicFactor = TotalEconomicFactor + temp1 * temp2
                j=j+1
            if TotalEconomicFactor != 0:
                break
        i=i+1

    factors = np.reshape(factors, (-1, 7))
    Sizefactors = factors.shape[0]
    PassiveGrowth = TotalEconomicFactor / TGRSales
    return PassiveGrowth, TotalEconomicFactor, TGRSales, RSaleBeg, RSaleEnd;

def extract_child_from_body_of_apg_event(event, child_item, mandatory): 
    try:
        passed_value = event['multiValueQueryStringParameters'][child_item][0]
        return passed_value
    except (KeyError, json.decoder.JSONDecodeError, TypeError) as e: #If passed value is empty then throw an error
        if(mandatory):
            logger.error(f"Could not find value for: {child_item}")
            raise 'ERROR: Must pass in all required values!'

def lambda_handler(event, context):
    RID=extract_child_from_body_of_apg_event(event, 'RID', mandatory=True)
    StartDate=extract_child_from_body_of_apg_event(event, 'StartDate', mandatory=True)
    EndDate=extract_child_from_body_of_apg_event(event, 'EndDate', mandatory=True)
    StartDate=StartDate.replace('-','')
    EndDate=EndDate.replace('-','')
    RID=int(RID)
    StartDate=int(StartDate)
    EndDate=int(EndDate)
    logger.info("RID: "+str(RID))
    logger.info("StartDate: "+str(StartDate))
    logger.info("EndDate: "+str(EndDate))
    logger.info(type(EndDate))

    user_count = getUserCount()
    updateUserCount(user_count)
    passiveGrowthVar, TotalEconomicFactor, TotalSalesGrowth, RSaleBeg, RSaleEnd = passiveGrowth(StartDate, EndDate, RID)
    logger.info("passiveGrowthVar: "+str(passiveGrowthVar))

    return {
        "statusCode": 200,
        'headers': {
            'Access-Control-Allow-Origin': os.environ['CORS_URL'],
            'Access-Control-Allow-Credentials': 'true',
            'Access-Control-Allow-Headers': 'Authorization',
            'Content-Type': 'application/json'
        },
        "body": json.dumps({
            "User count": str(user_count),
            "passiveGrowthVar": str(passiveGrowthVar),
            "BeginningValue": str(RSaleBeg),
            "EndingValue": str(RSaleEnd),
            "TotalSalesGrowth": str(TotalSalesGrowth),
            "InfluencerEconomicFactorImpact": str(TotalEconomicFactor),
        }),
    }
