import React, { useEffect, useState } from 'react';
import Container from '@mui/material/Container';
import Typography from '@mui/material/Typography';
import './App.css'; 
import Stack from '@mui/material/Stack';
import TextField from '@mui/material/TextField';
//import AdapterDateFns from '@mui/lab/AdapterDateFns';
//import LocalizationProvider from '@mui/lab/LocalizationProvider';
//import TimePicker from '@mui/lab/TimePicker';
//import DateTimePicker from '@mui/lab/DateTimePicker';
//import DesktopDatePicker from '@mui/lab/DesktopDatePicker';
//import MobileDatePicker from '@mui/lab/MobileDatePicker';

import githubLogo from 'images/githubLogo.png'

function App() {
  const [userCount, setUserCount] = useState(false);
  const [RID, setRID] = useState(10);
  const [StartDate, setStartDate] = useState(false);
  const [EndDate, setEndDate] = useState(false);
  const [passiveGrowthVar, setpassiveGrowthVar] = useState(false);
  const [BeginningValue, setBeginningValue] = useState(false);
  const [EndingValue, setEndingValue] = useState(false);
  const [TotalSalesGrowth, setTotalSalesGrowth] = useState(false);
  const [InfluencerEconomicFactorImpact, setInfluencerEconomicFactorImpact] = useState(false);

//  const [value, setValue] = React.useState(new Date('2014-08-18T21:11:54'));

//  const handleChange = (newValue) => {
//    setValue(newValue);
//  };

  //Special handling to use localhost SAM API if running locally via npm start(make run)
  const apiUrl = (process.env.NODE_ENV !== 'development') ? 'https://' + process.env.REACT_APP_USER_API_DOMAIN + '/users' : process.env.REACT_APP_USER_API_URL_LOCAL_SAM
  console.log('apiUrl: ', apiUrl)
  // console.log('RID: ', RID)
  // console.log('StartDate: ', StartDate)
  // console.log('EndDate: ', EndDate)

  //Prevent continuous reloading calling API each time
  useEffect(() => {
    if (RID && StartDate && EndDate){
      fetch(apiUrl+"?RID="+RID+"&StartDate="+StartDate+"&EndDate="+EndDate)
      .then(response => response.json())
      .then(response => {
        console.log(response)
        setUserCount(response['User count'])
        setpassiveGrowthVar(response['passiveGrowthVar'])
        setBeginningValue(response['BeginningValue'])
        setEndingValue(response['EndingValue'])
        setTotalSalesGrowth(response['TotalSalesGrowth'])
        setInfluencerEconomicFactorImpact(response['InfluencerEconomicFactorImpact'])
      })
      .catch(err => {
        console.log(err);
      });
    }
  }, [RID, StartDate, EndDate] );
  
  return (
    <div className="App">
      <header className="App-header">
        <Container className='header' maxWidth='md'>
          <Typography variant='h2'>
            Passive Appreciation
          </Typography>
          <Typography variant='h5'>
          Dr. Ashok Abbott
          </Typography>
          <br/>
          <Typography variant='h5'>
          Starting Date: 
          </Typography>
          <form>
            <input type="month" id="start" name="start"
              min="1992-01" max="2020-12" onChange={StartDate => setStartDate(StartDate.target.value)} ></input>
          </form>
          <Typography variant='h5'>
          Ending Date: 
          </Typography>
          <input type="month" id="end" name="end"
            min="1992-01" max="2020-12" onChange={EndDate => setEndDate(EndDate.target.value)} ></input>
          <Typography variant='h5'>
          Field/RID: 
          </Typography>
          <select onChange={RID => setRID(RID.target.value)} name="RIs" id="RIs">
            <option value="10">  Automobile Dealers </option>
            <option value="11">  New Car Dealers </option>
            <option value="12">  Used Car Dealers </option>
            <option value="14">  Furniture, Home Furn, Electronics, and Appliance Stores </option>
            <option value="15">  Furniture and Home Furnishings Stores </option>
            <option value="16">  Furniture Stores </option>
            <option value="17">  Home Furnishings Stores </option>
            <option value="18">  Floor Covering Stores </option>
            <option value="20">  Electronics and Appliance Stores </option>
            <option value="21">  Household Appliance Stores </option>
            <option value="23">  Building Mat. and Garden Equip. and Supplies Dealers </option>
            <option value="24">  Building Mat. and Supplies Dealers </option>
            <option value="26">  Hardware Stores </option>
            <option value="28">  Grocery Stores </option>
            <option value="29">  Supermarkets and Other Grocery (Except Convenience) Stores </option>
            <option value="30">  Beer, Wine, and Liquor Stores </option>
            <option value="31">  Health and Personal Care Stores </option>
            <option value="32">  Pharmacies and Drug Stores </option>
            <option value="33">  Gasoline Stations </option>
            <option value="34">  Clothing and Clothing Access. Stores </option>
            <option value="35">  Clothing Stores </option>
            <option value="38">  Family Clothing Stores </option>
            <option value="40">  Shoe Stores </option>
            <option value="41">  Jewelry Stores </option>
            <option value="42">  Sporting Goods, Hobby, Musical Instrument, and Book Stores </option>
            <option value="43">  Sporting Goods Stores </option>
            <option value="44">  Hobby, Toy, and Game Stores </option>
            <option value="46">  General Merchandise Stores </option>
            <option value="47">  Department Stores </option>
            <option value="48">  Discount Dept. Stores </option>
            <option value="50">  Other General Merchandise Stores </option>
            <option value="51">  Warehouse Clubs and Superstores </option>
            <option value="56">  Gift, Novelty, and Souvenir Stores </option>
            <option value="57">  Used Merchandise Stores </option>
            <option value="58">  Nonstore Retailers </option>
            <option value="61">  Food Services and Drinking Places </option>
            <option value="62">  Drinking Places </option>
            <option value="63">  Restaurants and Other Eating Places </option>
            <option value="64">  Full Service Restaurants </option>
            <option value="65">  Limited Service Eating Places </option>
          </select>
          <br/>
          <br/>
          <Typography>
          This demo shows the passive growth over the specified time frame.
          </Typography>
          <br/>
          <Typography variant='h5'>Passive Growth: {passiveGrowthVar}</Typography>
          <Typography variant='h6'>Total Influencer Economic Factor Impact: {InfluencerEconomicFactorImpact}</Typography>
          <Typography variant='h6'>Total sales Growth: {TotalSalesGrowth}</Typography>
          <Typography variant='h6'>Total Sales In {StartDate}: {BeginningValue}</Typography>
          <Typography variant='h6'>Total Sales In {EndDate}: {EndingValue}</Typography>
          <br/>
          <Typography className='visitorCounter'>Visitor Count: {userCount}</Typography>
        </Container>
      </header>
    </div>
  );
}

export default App;
