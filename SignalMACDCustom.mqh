//+------------------------------------------------------------------+
//|                                            SignalMACDCustom.mqh |
//+------------------------------------------------------------------+
#include <Expert\Expert.mqh>
#include <Expert\Signal\SignalMACD.mqh>
#include <Expert\Trailing\TrailingNone.mqh>
#include <Expert\Money\MoneyNone.mqh>

class CSignalMACDCustom : public CSignalMACD
  {
private:
   int               m_ma_fast_handle;
   int               m_ma_slow_handle;
   int               m_fast_period;
   int               m_slow_period;

public:
                     CSignalMACDCustom(void);
                    ~CSignalMACDCustom(void);
   virtual bool      InitIndicators(CIndicators *indicators);
   virtual double    Direction(void);

   void              FastMAPeriod(int value) { m_fast_period=value; }
   void              SlowMAPeriod(int value) { m_slow_period=value; }
   bool              ValidateCustomSettings(void);
  };

//+------------------------------------------------------------------+
//| Constructor                                                      |
//+------------------------------------------------------------------+
CSignalMACDCustom::CSignalMACDCustom(void) : m_ma_fast_handle(INVALID_HANDLE),
                                             m_ma_slow_handle(INVALID_HANDLE),
                                             m_fast_period(3),
                                             m_slow_period(16)
  {
   if(!ValidateCustomSettings())
      Print("CSignalMACDCustom constructor: Warning - Invalid custom settings");
  }

//+------------------------------------------------------------------+
//| Destructor                                                       |
//+------------------------------------------------------------------+
CSignalMACDCustom::~CSignalMACDCustom(void)
  {
   IndicatorRelease(m_ma_fast_handle);
   IndicatorRelease(m_ma_slow_handle);
  }

//+------------------------------------------------------------------+
//| Validate custom settings                                         |
//+------------------------------------------------------------------+
bool CSignalMACDCustom::ValidateCustomSettings(void)
  {
   if(m_fast_period<=0 || m_slow_period<=0 || m_fast_period>=m_slow_period)
     {
      Print("CSignalMACDCustom::ValidateCustomSettings: Invalid MA periods");
      return false;
     }
   return true;
  }

//+------------------------------------------------------------------+
//| Initialize indicators                                            |
//+------------------------------------------------------------------+
bool CSignalMACDCustom::InitIndicators(CIndicators *indicators)
  {
   if(!CSignalMACD::InitIndicators(indicators))
      return(false);

   m_ma_fast_handle=iMA(m_symbol.Name(),m_period,m_fast_period,0,MODE_SMA,PRICE_CLOSE);
   m_ma_slow_handle=iMA(m_symbol.Name(),m_period,m_slow_period,0,MODE_SMA,PRICE_CLOSE);

   if(m_ma_fast_handle==INVALID_HANDLE || m_ma_slow_handle==INVALID_HANDLE)
      return(false);

   return(true);
  }

//+------------------------------------------------------------------+
//| Generation a trading signal                                      |
//+------------------------------------------------------------------+
double CSignalMACDCustom::Direction(void)
  {
   double fast_ma[2], slow_ma[2];
   if(CopyBuffer(m_ma_fast_handle,0,0,2,fast_ma)!=2 || CopyBuffer(m_ma_slow_handle,0,0,2,slow_ma)!=2)
      return(0);

   ArraySetAsSeries(fast_ma,true);
   ArraySetAsSeries(slow_ma,true);

   if(fast_ma[1]<=slow_ma[1] && fast_ma[0]>slow_ma[0] && slow_ma[0]>0 && slow_ma[0]>slow_ma[1])
      return(1);  // Buy signal

   return(CSignalMACD::Direction());  // Use original MACD logic for other cases
  }