//+------------------------------------------------------------------+
//|                     USATEC.mq5 - Incorporando MACD Nativo        |
//+------------------------------------------------------------------+
#property strict

#include <Trade\Trade.mqh>
#include <SmoothAlgorithms.mqh>

// Parâmetros do MACD
input int Fast_MA = 12;                // Período da média rápida
input int Slow_MA = 26;                // Período da média lenta
input int Signal_SMA = 9;              // Período da linha de sinal
input ENUM_MA_METHOD MA_Method_ = MODE_EMA; // Método de suavização
input ENUM_APPLIED_PRICE AppliedPrice = PRICE_CLOSE;  // Preço aplicado

// Parâmetros de entrada do script
input double TakeProfit = 4000;
input double StopLoss = 1500;
input double LotSize = 0.2;
input int DEMA1_Period = 10;
input int DEMA2_Period = 20;
input int DEMA3_Period = 100;
input int RSI_Period = 10;
input int RSI_Buy_Threshold = 30;       // Threshold para compra
input int RSI_Sell_Threshold = 70;      // Threshold para venda
input int Stoch_Buy_Threshold = 20;     // Threshold do Stochastic para compra
input int Stoch_Sell_Threshold = 80;    // Threshold do Stochastic para venda
input int Stoch_K = 10;
input int Stoch_D = 3;
input int Stoch_Slowing = 3;
input int ATR_Period = 5;
input int ADX_Period = 16;
input double ATR_Threshold = 10;
input double ADX_Threshold = 25;

// Buffers dos indicadores
double dema1Buffer[], dema2Buffer[], dema3Buffer[];
double MACDLineBuffer[], SignalLineBuffer[], HistogramBuffer[];
double rsiBuffer[];
double stochKBuffer[], stochDBuffer[];
double atrBuffer[], adxBuffer[];
double plusDiBuffer[], minusDiBuffer[];

// Arrays de preços
double openPrices[], highPrices[], lowPrices[], closePrices[];

// Variáveis de controle de sobrecompra/sobrevenda
bool rsi_oversold = false, rsi_overbought = false;
bool stoch_oversold = false, stoch_overbought = false;

// Manipuladores dos indicadores
int dema1Handle;
int dema2Handle;
int dema3Handle;
int rsiHandle;
int stochHandle;
int atrHandle;
int adxHandle;

// Criação de instância da classe CTrade
CTrade Trade;

// Variáveis de status para cruzamentos de DEMAs
bool dema10_above_100 = false, dema20_above_100 = false;
bool dema10_below_100 = false, dema20_below_100 = false;
bool dema10_crossed_above = false, dema20_crossed_above = false;
bool dema10_crossed_below = false, dema20_crossed_below = false;

// Variáveis para inicialização correta do MACD
int macd_start = 0;
int start = 0;

//+------------------------------------------------------------------+
//| Inicialização do expert                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    // Inicialização das variáveis de início de cálculo
    macd_start = MathMax(Fast_MA, Slow_MA);
    start = macd_start + Signal_SMA + 1;

    int totalBars = Bars(_Symbol, PERIOD_CURRENT);

    // Configurar buffers
    ArrayResize(MACDLineBuffer, totalBars);
    ArrayResize(SignalLineBuffer, totalBars);
    ArrayResize(HistogramBuffer, totalBars);

    ArraySetAsSeries(MACDLineBuffer, true);
    ArraySetAsSeries(SignalLineBuffer, true);
    ArraySetAsSeries(HistogramBuffer, true);

    // Criar manipuladores para os indicadores
    dema1Handle = iDEMA(_Symbol, PERIOD_CURRENT, DEMA1_Period, 0, PRICE_CLOSE);
    dema2Handle = iDEMA(_Symbol, PERIOD_CURRENT, DEMA2_Period, 0, PRICE_CLOSE);
    dema3Handle = iDEMA(_Symbol, PERIOD_CURRENT, DEMA3_Period, 0, PRICE_CLOSE);
    rsiHandle = iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE);
    stochHandle = iStochastic(_Symbol, PERIOD_CURRENT, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH);
    atrHandle = iATR(_Symbol, PERIOD_CURRENT, ATR_Period);
    adxHandle = iADX(_Symbol, PERIOD_CURRENT, ADX_Period);

    // Verifica se todos os manipuladores estão válidos
    if (dema1Handle == INVALID_HANDLE || dema2Handle == INVALID_HANDLE || dema3Handle == INVALID_HANDLE || 
        rsiHandle == INVALID_HANDLE || stochHandle == INVALID_HANDLE || 
        atrHandle == INVALID_HANDLE || adxHandle == INVALID_HANDLE)
    {
        PrintFormat("Erro ao criar manipuladores de indicadores, código de erro %d", GetLastError());
        return INIT_FAILED;
    }
    
   // Print a message to the log
   Print("Expert initialized");
   
   // Calculate and print the moving average
   double movingAverage = CalculateMovingAverage();
   Print("Moving Average: ", movingAverage);
   


    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função principal de execução a cada tick                         |
//+------------------------------------------------------------------+
void OnTick()
{
    int minBars = MathMax(MathMax(DEMA3_Period, ADX_Period), ATR_Period) + start;
    int totalBars = Bars(_Symbol, PERIOD_CURRENT);
    
    if (totalBars <= minBars)
    {
        Print("Barras insuficientes para cálculo");
        return;
    }

    // Obter os preços necessários para o cálculo do MACD
    if (CopyClose(_Symbol, PERIOD_CURRENT, 0, totalBars, closePrices) < totalBars ||
        CopyOpen(_Symbol, PERIOD_CURRENT, 0, totalBars, openPrices) < totalBars ||
        CopyHigh(_Symbol, PERIOD_CURRENT, 0, totalBars, highPrices) < totalBars ||
        CopyLow(_Symbol, PERIOD_CURRENT, 0, totalBars, lowPrices) < totalBars)
    {
        Print("Erro ao copiar preços");
        return;
    }

    // Calcular MACD usando a lógica nativa
    CalcularMACD(totalBars);

    // Copiar dados para os buffers adicionais
    if (CopyBuffer(dema1Handle, 0, 0, 3, dema1Buffer) != 3 ||
        CopyBuffer(dema2Handle, 0, 0, 3, dema2Buffer) != 3 ||
        CopyBuffer(dema3Handle, 0, 0, 3, dema3Buffer) != 3)
    {
        Print("Erro ao copiar dados da DEMA");
        return;
    }

    if (CopyBuffer(rsiHandle, 0, 0, 3, rsiBuffer) != 3 ||
        CopyBuffer(stochHandle, 0, 0, 3, stochKBuffer) != 3 ||
        CopyBuffer(stochHandle, 1, 0, 3, stochDBuffer) != 3 ||
        CopyBuffer(atrHandle, 0, 0, 2, atrBuffer) != 2 ||
        CopyBuffer(adxHandle, 0, 0, 2, adxBuffer) != 2 ||
        CopyBuffer(adxHandle, 1, 0, 2, plusDiBuffer) != 2 ||
        CopyBuffer(adxHandle, 2, 0, 2, minusDiBuffer) != 2)
    {
        Print("Erro ao copiar dados dos indicadores auxiliares");
        return;
    }

    // Atualiza status de cruzamento e posição relativa ao DEMA100
    ValidarStatusDEMA();

    // Atualiza status de sobrecompra/sobrevenda dos indicadores
    AtualizarStatusSobrecompraSobrevenda();

    // Log de cruzamentos
    LogCruzamento();

    // Condições de compra e venda baseadas nos status
    if (!dema10_above_100 && !dema20_above_100) // Ambos vendidos
    {
        if (VerificaCondicoesVenda(HistogramBuffer[0]))
            ExecutaVenda();
    }

    if (dema10_above_100 && dema20_above_100) // Ambos comprados
    {
        if (VerificaCondicoesCompra(HistogramBuffer[0]))
            ExecutaCompra();
    }
}

double CalculateMovingAverage()
  {
   // Define the period for the moving average
   int period = 14;
   
   // Initialize sum of prices
   double sum = 0;
   
   // Loop through the last 'period' number of bars
   for(int i = 0; i < period; i++)
     {
      // Access the closing price of each bar
      double closePrice = iClose(NULL, 0, i);
      
      // Add the closing price to the sum
      sum += closePrice;
     }
   
   // Calculate the average
   double average = sum / period;
   
   // Return the moving average
   return average;
  }
//+------------------------------------------------------------------+
//| Função que calcula o MACD baseado no exemplo fornecido           |
//+------------------------------------------------------------------+
void CalcularMACD(int rates_total)
{
    int prev_calculated = 0;
    static CMoving_Average MA1, MA2, MA3;

    if(rates_total < start) return;

    // Certifique-se de que os buffers têm tamanho suficiente
    ArrayResize(MACDLineBuffer, rates_total);
    ArrayResize(SignalLineBuffer, rates_total);
    ArrayResize(HistogramBuffer, rates_total);

    // Calcular as médias móveis e o MACD
    for(int bar = rates_total - 1; bar >= 0; bar--)
    {

// Certainly! MQL5 is a programming language used for developing trading strategies and indicators in the MetaTrader 5 platform. If you have a specific piece of code you'd like explained, please provide it. However, I can provide a general explanation of a common type of MQL5 code related to price handling.
// 
// Let's consider a simple example where we calculate a moving average of the closing prices of a financial instrument:
// 

//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+

//+------------------------------------------------------------------+
//| Custom function to calculate moving average                      |
//+------------------------------------------------------------------+


// 
// ### Explanation:
// 
// 1. **OnInit Function**: This is the initialization function for the Expert Advisor (EA). It is called when the EA is loaded onto a chart. Here, it prints a message to the log and calculates a moving average by calling the `CalculateMovingAverage` function.
// 
// 2. **CalculateMovingAverage Function**: This custom function calculates a simple moving average of the closing prices over a specified period (14 in this case).
// 
//    - **Period Definition**: The variable `period` defines how many bars (or candlesticks) are used to calculate the moving average.
//    
//    - **Sum Initialization**: The variable `sum` is initialized to zero to accumulate the closing prices.
//    
//    - **Loop Through Bars**: A `for` loop iterates over the last `period` number of bars. The function `iClose(NULL, 0, i)` is used to get the closing price of the `i-th` bar. The `NULL` and `0` parameters specify the current symbol and timeframe, respectively.
//    
//    - **Calculate Average**: After summing up the closing prices, the average is calculated by dividing the sum by the period.
// 
// 3. **Return Value**: The calculated moving average is returned to the `OnInit` function, which then prints it to the log.
// 
// This example demonstrates how to access price data and perform basic calculations in MQL5. If you have a specific piece of code you'd like help with, feel free to share it!
// 
        double price_ = PriceSeries(PRICE_CLOSE, bar, openPrices, lowPrices, highPrices, closePrices);
// In MQL5, the `PriceSeries` function is not a standard built-in function. It seems like you are trying to create a custom function to get a specific price from the price series arrays (open, low, high, close). If you want to retrieve the close price for a specific bar, you can directly access the `closePrices` array using the bar index. Here's how you can do it:
// 

double price_ = closePrices[bar];

// 
// If you want to create a custom function similar to `PriceSeries` to retrieve different types of prices, you can define it like this:
// 

enum PriceType
{
    PRICE_OPEN,
    PRICE_LOW,
    PRICE_HIGH,
    PRICE_CLOSE
};

double PriceSeries(PriceType priceType, int bar, double openPrices[], double lowPrices[], double highPrices[], double closePrices[])
{
    switch(priceType)
    {
        case PRICE_OPEN:
            return openPrices[bar];
        case PRICE_LOW:
            return lowPrices[bar];
        case PRICE_HIGH:
            return highPrices[bar];
        case PRICE_CLOSE:
            return closePrices[bar];
        default:
            return 0.0; // Return a default value if the price type is not recognized
    }
}

// 
// You can then call this function like this:
// 

double price_ = PriceSeries(PRICE_CLOSE, bar, openPrices, lowPrices, highPrices, closePrices);

// 
// This custom function allows you to specify which type of price you want to retrieve (open, low, high, or close) for a given bar index.
// 

        double fast_ma = MA1.MASeries(0, prev_calculated, rates_total, Fast_MA, MA_Method_, price_, bar, true);
        double slow_ma = MA2.MASeries(0, prev_calculated, rates_total, Slow_MA, MA_Method_, price_, bar, true);

        if(fast_ma == 0 || slow_ma == 0) {
            PrintFormat("Erro no cálculo da média móvel: Fast_MA=%.5f, Slow_MA=%.5f", fast_ma, slow_ma);
            continue;
        }

        MACDLineBuffer[bar] = fast_ma - slow_ma;
        SignalLineBuffer[bar] = MA3.SMASeries(0, prev_calculated, rates_total, Signal_SMA, MACDLineBuffer[bar], bar, true);

        if(bar > rates_total - 1 - start)
            HistogramBuffer[bar] = 0.0;
        else
            HistogramBuffer[bar] = MACDLineBuffer[bar] - SignalLineBuffer[bar];
    }
}

//+------------------------------------------------------------------+
//| Função que valida e atualiza o status dos cruzamentos            |
//+------------------------------------------------------------------+
void ValidarStatusDEMA()
{
    // Verificar cruzamentos de DEMA10 com DEMA100
    dema10_crossed_above = (dema1Buffer[1] < dema3Buffer[1] && dema1Buffer[0] > dema3Buffer[0]);
    dema10_crossed_below = (dema1Buffer[1] > dema3Buffer[1] && dema1Buffer[0] < dema3Buffer[0]);

    // Verificar cruzamentos de DEMA20 com DEMA100
    dema20_crossed_above = (dema2Buffer[1] < dema3Buffer[1] && dema2Buffer[0] > dema3Buffer[0]);
    dema20_crossed_below = (dema2Buffer[1] > dema3Buffer[1] && dema2Buffer[0] < dema3Buffer[0]);

    // Atualizar status de comprado/vendido baseado nos cruzamentos
    dema10_above_100 = dema10_crossed_above || dema1Buffer[0] > dema3Buffer[0];
    dema20_above_100 = dema20_crossed_above || dema2Buffer[0] > dema3Buffer[0];

    dema10_below_100 = dema10_crossed_below || dema1Buffer[0] < dema3Buffer[0];
    dema20_below_100 = dema20_crossed_below || dema2Buffer[0] < dema3Buffer[0];
}

//+------------------------------------------------------------------+
//| Atualiza o status de sobrecompra/sobrevenda dos indicadores      |
//+------------------------------------------------------------------+
void AtualizarStatusSobrecompraSobrevenda()
{
    // RSI
    rsi_oversold = (rsiBuffer[0] <= RSI_Buy_Threshold);
    rsi_overbought = (rsiBuffer[0] >= RSI_Sell_Threshold);

    // Estocástica
    stoch_oversold = (stochKBuffer[0] <= Stoch_Buy_Threshold);
    stoch_overbought = (stochKBuffer[0] >= Stoch_Sell_Threshold);
}

// Verificações de cruzamento
bool CruzouAbaixo(double &buffer1[], double &buffer2[])
{
    return (buffer1[1] > buffer2[1] && buffer1[0] < buffer2[0]);
}

bool CruzouAcima(double &buffer1[], double &buffer2[])
{
    return (buffer1[1] < buffer2[1] && buffer1[0] > buffer2[0]);
}

//+------------------------------------------------------------------+
//| Loga o estado atual dos cruzamentos para análise                 |
//+------------------------------------------------------------------+
void LogCruzamento()
{
    if (dema10_crossed_above)
    {
        PrintFormat("DEMA10 cruzou acima de DEMA100: DEMA10=%.5f, DEMA100=%.5f", dema1Buffer[0], dema3Buffer[0]);
    }

    if (dema20_crossed_above)
    {
        PrintFormat("DEMA20 cruzou acima de DEMA100: DEMA20=%.5f, DEMA100=%.5f", dema2Buffer[0], dema3Buffer[0]);
    }

    if (dema10_crossed_below)
    {
        PrintFormat("DEMA10 cruzou abaixo de DEMA100: DEMA10=%.5f, DEMA100=%.5f", dema1Buffer[0], dema3Buffer[0]);
    }

    if (dema20_crossed_below)
    {
        PrintFormat("DEMA20 cruzou abaixo de DEMA100: DEMA20=%.5f, DEMA100=%.5f", dema2Buffer[0], dema3Buffer[0]);
    }
}

//+------------------------------------------------------------------+
//| Verificação das condições de venda                               |
//+------------------------------------------------------------------+
bool VerificaCondicoesVenda(double macdHistogram)
{
    if (macdHistogram < 0 &&
        SignalLineBuffer[0] < 0 && // Condição do sinal MACD para venda
        rsi_overbought && // Condição de sobrecompra do RSI
        stoch_overbought && // Condição de sobrecompra da estocástica
        atrBuffer[0] > ATR_Threshold &&
        adxBuffer[0] > ADX_Threshold &&
        plusDiBuffer[0] < minusDiBuffer[0]) // Ajuste da comparação DI+ < DI-
    {
        return true;
    }
    else if (!dema10_above_100 && !dema20_above_100)
    {
        PrintFormat("Falha nas condições de venda: MACD=%.5f, RSI=%.5f (Overbought=%s), StochK=%.5f (Overbought=%s), StochD=%.5f, ATR=%.5f, ADX=%.5f, plusDI=%.5f, minusDI=%.5f",
                    macdHistogram, rsiBuffer[0], rsi_overbought ? "true" : "false", 
                    stochKBuffer[0], stoch_overbought ? "true" : "false",
                    stochDBuffer[0], atrBuffer[0], adxBuffer[0], plusDiBuffer[0], minusDiBuffer[0]);
    }
    return false;
}

//+------------------------------------------------------------------+
//| Verificação das condições de compra                              |
//+------------------------------------------------------------------+
bool VerificaCondicoesCompra(double macdHistogram)
{
    if (macdHistogram > 0 &&
        SignalLineBuffer[0] > 0 && // Condição do sinal MACD para compra
        rsi_oversold && // Condição de sobrevenda do RSI
        stoch_oversold && // Condição de sobrevenda da estocástica
        atrBuffer[0] > ATR_Threshold &&
        adxBuffer[0] > ADX_Threshold &&
        plusDiBuffer[0] > minusDiBuffer[0]) // Ajuste da comparação DI+ > DI-
    {
        return true;
    }
    else if (dema10_above_100 && dema20_above_100)
    {
        PrintFormat("Falha nas condições de compra: MACD=%.5f, RSI=%.5f (Oversold=%s), StochK=%.5f (Oversold=%s), StochD=%.5f, ATR=%.5f, ADX=%.5f, plusDI=%.5f, minusDI=%.5f",
                    macdHistogram, rsiBuffer[0], rsi_oversold ? "true" : "false", 
                    stochKBuffer[0], stoch_oversold ? "true" : "false",
                    stochDBuffer[0], atrBuffer[0], adxBuffer[0], plusDiBuffer[0], minusDiBuffer[0]);
    }
    return false;
}

//+------------------------------------------------------------------+
//| Função para executar venda                                       |
//+------------------------------------------------------------------+
void ExecutaVenda()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_BID);
    double tp = price - TakeProfit * _Point;
    double sl = price + StopLoss * _Point;

    if (!Trade.Sell(LotSize, _Symbol, price, sl, tp, "Sell Order"))
    {
        Print("Falha ao colocar ordem de venda: ", Trade.ResultRetcodeDescription());
    }
}

//+------------------------------------------------------------------+
//| Função para executar compra                                      |
//+------------------------------------------------------------------+
void ExecutaCompra()
{
    double price = SymbolInfoDouble(_Symbol, SYMBOL_ASK);
    double tp = price + TakeProfit * _Point;
    double sl = price - StopLoss * _Point;

    if (!Trade.Buy(LotSize, _Symbol, price, sl, tp, "Buy Order"))
    {
        Print("Falha ao colocar ordem de compra: ", Trade.ResultRetcodeDescription());
    }
}