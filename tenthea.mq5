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
input int AppliedPrice = PRICE_CLOSE;  // Preço aplicado

// Arrays de preços
double openPrices[], highPrices[], lowPrices[], closePrices[];

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

    // Configurar buffers
    SetIndexBuffer(0, dema1Buffer, INDICATOR_DATA);
    SetIndexBuffer(1, dema2Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, dema3Buffer, INDICATOR_DATA);
    
    SetIndexBuffer(0, MACDLineBuffer, INDICATOR_DATA);
    SetIndexBuffer(1, SignalLineBuffer, INDICATOR_DATA);
    SetIndexBuffer(2, HistogramBuffer, INDICATOR_DATA);
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

    // Calcular MACD usando a lógica nativa
    CalcularMACD();

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

//+------------------------------------------------------------------+
//| Função que calcula o MACD baseado no exemplo fornecido           |
//+------------------------------------------------------------------+
void CalcularMACD()
{
    int rates_total = Bars(_Symbol, PERIOD_CURRENT);
    int prev_calculated = 0;
    double price_, fast_ma, slow_ma;
    static CMoving_Average MA1, MA2, MA3;

    if(rates_total < start) return;

    for(int bar = rates_total - 1; bar >= 0; bar--)
    {
        price_ = PriceSeries(AppliedPrice, bar, openPrices, lowPrices, highPrices, closePrices);
        fast_ma = MA1.MASeries(rates_total - 1, prev_calculated, rates_total, Fast_MA, MA_Method_, price_, bar, true);
        slow_ma = MA2.MASeries(rates_total - 1, prev_calculated, rates_total, Slow_MA, MA_Method_, price_, bar, true);
        MACDLineBuffer[bar] = fast_ma - slow_ma;
        SignalLineBuffer[bar] = MA3.SMASeries(rates_total - 1 - macd_start, prev_calculated, rates_total, Signal_SMA, MACDLineBuffer[bar], bar, true);

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