//+------------------------------------------------------------------+
//|                                                   ExpertMACD.mq5 |
//|                             Copyright 2000-2024, MetaQuotes Ltd. |
//|                                             https://www.mql5.com |
//+------------------------------------------------------------------+
#property copyright "Copyright 2000-2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.02"

#property copyright "Copyright 2000-2024, MetaQuotes Ltd."
#property link      "https://www.mql5.com"
#property version   "1.02"

#include <Expert\Signal\SignalMACDCustom.mqh>
#include <Expert\Trailing\TrailingNone.mqh>
#include <Expert\Money\MoneyFixedLot.mqh>

//--- Input parameters
input int    Inp_Signal_MACD_PeriodFast  = 3;
input int    Inp_Signal_MACD_PeriodSlow  = 10;
input int    Inp_Signal_MACD_PeriodSignal= 16;
input int    Inp_Signal_MACD_TakeProfit  = 1000;
input int    Inp_Signal_MACD_StopLoss    = 750;
input int    Inp_Signal_MA_FastPeriod    = 3;
input int    Inp_Signal_MA_SlowPeriod    = 16;
input double Inp_Money_FixLot_Percent    = 10.0;
input double Inp_Money_FixLot_Lots       = 0.2;

//--- Global variables
CSignalMACDCustom *Signal;
CTrailingNone *Trailing;
CMoneyFixedLot *Money;

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
   //--- Create Signal
   Signal = new CSignalMACDCustom();
   if(Signal == NULL)
     {
      printf(__FUNCTION__+": error creating signal");
      return(INIT_FAILED);
     }
   //--- Set parameters for Signal
   Signal.PeriodFast(Inp_Signal_MACD_PeriodFast);
   Signal.PeriodSlow(Inp_Signal_MACD_PeriodSlow);
   Signal.PeriodSignal(Inp_Signal_MACD_PeriodSignal);
   Signal.TakeLevel(Inp_Signal_MACD_TakeProfit);
   Signal.StopLevel(Inp_Signal_MACD_StopLoss);
   Signal.FastMAPeriod(Inp_Signal_MA_FastPeriod);
   Signal.SlowMAPeriod(Inp_Signal_MA_SlowPeriod);

   //--- Validate signal settings
   //if(!Signal->ValidateCustomSettings())
   //  {
   //   printf(__FUNCTION__+": error in signal settings");
    //  delete Signal;
   //   return(INIT_PARAMETERS_INCORRECT);
   //  }

   Signal.FastMAPeriod(Inp_Signal_MA_FastPeriod);
   Signal.SlowMAPeriod(Inp_Signal_MA_SlowPeriod);
   
   if(!Signal.ValidateCustomSettings())
   {
       Print("Invalid signal settings");
       // Trate o erro apropriadamente
   }
   //--- Create Trailing
   Trailing = new CTrailingNone();
   if(Trailing == NULL)
     {
      printf(__FUNCTION__+": error creating trailing");
      delete Signal;
      return(INIT_FAILED);
     }

   //--- Create Money Management
   Money = new CMoneyFixedLot();
   if(Money == NULL)
     {
      printf(__FUNCTION__+": error creating money management");
      delete Signal;
      delete Trailing;
      return(INIT_FAILED);
     }
   //--- Set parameters for Money Management
   Money.Percent(Inp_Money_FixLot_Percent);
   Money.Lots(Inp_Money_FixLot_Lots);

   //--- Initialization success
   return(INIT_SUCCEEDED);
  }

//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
   //--- Clean up resources
   if(Signal != NULL) delete Signal;
   if(Trailing != NULL) delete Trailing;
   if(Money != NULL) delete Money;
  }
  

//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
   // Your MACD and custom logic integration can go here
   double dir = Signal.Direction();
   if(dir > 0)
   {
       // Logic for buy signal
       Print("Buy signal detected");
   }
   else if(dir < 0)
   {
       // Logic for sell signal, if implemented
       Print("Sell signal detected");
   }
  }