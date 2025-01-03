
//+------------------------------------------------------------------+
//|                                                         USATEC.mq5|
//|                        Automated Trading Script for USATEC       |
//+------------------------------------------------------------------+


#include <Trade\Trade.mqh>

// Propriedades dos indicadores
#property strict
#property indicator_chart_window
#property indicator_buffers 3
#property indicator_plots 3
#property indicator_label1 "DEMA10"
#property indicator_type1 DRAW_LINE
#property indicator_color1 clrMagenta
#property indicator_width1 1
#property indicator_label2 "DEMA20"
#property indicator_type2 DRAW_LINE
#property indicator_color2 clrDarkOrange
#property indicator_width2 1
#property indicator_label3 "DEMA100"
#property indicator_type3 DRAW_LINE
#property indicator_color3 clrDarkOrchid
#property indicator_width3 1

// Parâmetros de entrada
input double TakeProfit = 4000;
input double StopLoss = 1500;
input double LotSize = 0.2;
input int DEMA1_Period = 10;
input int DEMA2_Period = 20;
input int DEMA3_Period = 100;
input int RSI_Period = 10;
input int Stoch_K = 10;
input int Stoch_D = 3;
input int Stoch_Slowing = 3;
input int ATR_Period = 5;
input int ADX_Period = 16;
input double ATR_Threshold = 10;
input double ADX_Threshold = 25;

// Símbolo a ser negociado
string symbol = "UsaTec";

// Buffers dos indicadores
double dema1Buffer[], dema2Buffer[], dema3Buffer[];
double macdBuffer[], rsiBuffer[];
double stochKBuffer[], stochDBuffer[];
double atrBuffer[], adxBuffer[];
double plusDiBuffer[], minusDiBuffer[];

bool dema10_crossed_down;
bool dema20_crossed_down;
bool dema10_crossed_up; 
bool dema20_crossed_up;

// Criação de instância da classe CTrade
CTrade Trade;

//+------------------------------------------------------------------+
//| Inicialização do expert                                          |
//+------------------------------------------------------------------+
int OnInit()
{
    SetIndexBuffer(0, dema1Buffer, INDICATOR_DATA);
    SetIndexBuffer(1, dema2Buffer, INDICATOR_DATA);
    SetIndexBuffer(2, dema3Buffer, INDICATOR_DATA);

    PlotIndexSetInteger(0, PLOT_LINE_COLOR, clrMagenta);
    PlotIndexSetInteger(1, PLOT_LINE_COLOR, clrDarkOrange);
    PlotIndexSetInteger(2, PLOT_LINE_COLOR, clrDarkOrchid);

    return INIT_SUCCEEDED;
}

//+------------------------------------------------------------------+
//| Função principal de execução a cada tick                         |
//+------------------------------------------------------------------+
void OnTick()
{
    if(Bars(_Symbol, PERIOD_CURRENT) < MathMax(DEMA3_Period, MathMax(ADX_Period, ATR_Period)))
        return;

    // Configura os arrays como séries
    ArraySetAsSeries(dema1Buffer, true);
    ArraySetAsSeries(dema2Buffer, true);
    ArraySetAsSeries(dema3Buffer, true);
    ArraySetAsSeries(macdBuffer, true);
    ArraySetAsSeries(rsiBuffer, true);
    ArraySetAsSeries(stochKBuffer, true);
    ArraySetAsSeries(stochDBuffer, true);
    ArraySetAsSeries(atrBuffer, true);
    ArraySetAsSeries(adxBuffer, true);
    ArraySetAsSeries(plusDiBuffer, true);
    ArraySetAsSeries(minusDiBuffer, true);

    // Copia os dados dos indicadores para os buffers
    CopyBuffer(iDEMA(_Symbol, PERIOD_CURRENT, DEMA1_Period, 0, PRICE_CLOSE), 0, 0, 2, dema1Buffer);
    CopyBuffer(iDEMA(_Symbol, PERIOD_CURRENT, DEMA2_Period, 0, PRICE_CLOSE), 0, 0, 2, dema2Buffer);
    CopyBuffer(iDEMA(_Symbol, PERIOD_CURRENT, DEMA3_Period, 0, PRICE_CLOSE), 0, 0, 2, dema3Buffer);
    CopyBuffer(iMACD(_Symbol, PERIOD_CURRENT, 3, 10, 16, PRICE_CLOSE), 2, 0, 2, macdBuffer);
    CopyBuffer(iRSI(_Symbol, PERIOD_CURRENT, RSI_Period, PRICE_CLOSE), 0, 0, 2, rsiBuffer);
    CopyBuffer(iStochastic(_Symbol, PERIOD_CURRENT, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH), 0, 0, 2, stochKBuffer);
    CopyBuffer(iStochastic(_Symbol, PERIOD_CURRENT, Stoch_K, Stoch_D, Stoch_Slowing, MODE_SMA, STO_LOWHIGH), 1, 0, 2, stochDBuffer);
    CopyBuffer(iATR(_Symbol, PERIOD_CURRENT, ATR_Period), 0, 0, 1, atrBuffer);
    CopyBuffer(iADX(_Symbol, PERIOD_CURRENT, ADX_Period), 0, 0, 1, adxBuffer);
    CopyBuffer(iADX(_Symbol, PERIOD_CURRENT, ADX_Period), 1, 0, 1, plusDiBuffer);
    CopyBuffer(iADX(_Symbol, PERIOD_CURRENT, ADX_Period), 2, 0, 1, minusDiBuffer);

    // Flags para cruzamentos e versões simplificadas
    static bool dema10_crossed_down = false, dema20_crossed_down = false;
    static bool dema10_crossed_up = false, dema20_crossed_up = false;

    // Verificação de cruzamentos e logs para venda
    if (!dema10_crossed_down && CruzouAbaixo(dema1Buffer, dema3Buffer))
        LogCruzamento("venda", "DEMA10", dema1Buffer, dema2Buffer, dema3Buffer, dema10_crossed_down);

    if (!dema20_crossed_down && CruzouAbaixo(dema2Buffer, dema3Buffer))
        LogCruzamento("venda", "DEMA20", dema1Buffer, dema2Buffer, dema3Buffer, dema20_crossed_down);

    if (dema10_crossed_down && dema20_crossed_down && VerificaCondicoesVenda())
        ExecutaVenda();

    // Reseta flags de venda se cruzar para cima
    if (dema10_crossed_down && CruzouAcima(dema1Buffer, dema3Buffer)) ResetFlagsVenda();
    if (dema20_crossed_down && CruzouAcima(dema2Buffer, dema3Buffer)) ResetFlagsVenda();

    // Verificação de cruzamentos e logs para compra
    if (!dema10_crossed_up && CruzouAcima(dema1Buffer, dema3Buffer))
        LogCruzamento("compra", "DEMA10", dema1Buffer, dema2Buffer, dema3Buffer, dema10_crossed_up);

    if (!dema20_crossed_up && CruzouAcima(dema2Buffer, dema3Buffer))
        LogCruzamento("compra", "DEMA20", dema1Buffer, dema2Buffer, dema3Buffer, dema20_crossed_up);

    if (dema10_crossed_up && dema20_crossed_up && VerificaCondicoesCompra())
        ExecutaCompra();

    // Reseta flags de compra se cruzar para baixo
    if (dema10_crossed_up && CruzouAbaixo(dema1Buffer, dema3Buffer)) ResetFlagsCompra();
    if (dema20_crossed_up && CruzouAbaixo(dema2Buffer, dema3Buffer)) ResetFlagsCompra();
}

// Funções auxiliares para verificar cruzamentos e execução de ordens
bool CruzouAbaixo(double &buffer1[], double &buffer2[])
{
    return(buffer1[1] > buffer2[1] && buffer1[0] < buffer2[0]);
}

bool CruzouAcima(double &buffer1[], double &buffer2[])
{
    return(buffer1[1] < buffer2[1] && buffer1[0] > buffer2[0]);
}

void LogCruzamento(string tipo, string dema, double &dema1[], double &dema2[], double &dema3[], bool &crossed)
{
    crossed = true;
    PrintFormat("Condição de %s satisfeita (%s cruzou): DEMA10=%.5f, DEMA20=%.5f, DEMA100=%.5f",
                tipo, dema, dema1[0], dema2[0], dema3[0]);
}

bool VerificaCondicoesVenda()
{
    if (macdBuffer[1] > 0 && macdBuffer[0] < 0 &&
        rsiBuffer[0] > 50 &&
        stochKBuffer[0] > 50 && stochDBuffer[0] > stochKBuffer[0] &&
        atrBuffer[0] > ATR_Threshold &&
        adxBuffer[0] > ADX_Threshold &&
        minusDiBuffer[1] > plusDiBuffer[1] && minusDiBuffer[0] < plusDiBuffer[0])
    {
        return true;
    }
    else
    {
        PrintFormat("Falha nas condições de venda: MACD=%.5f, RSI=%.5f, StochK=%.5f, StochD=%.5f, ATR=%.5f, ADX=%.5f, plusDI=%.5f, minusDI=%.5f",
                    macdBuffer[0], rsiBuffer[0], stochKBuffer[0], stochDBuffer[0],
                    atrBuffer[0], adxBuffer[0], plusDiBuffer[0], minusDiBuffer[0]);
        return false;
    }
}

bool VerificaCondicoesCompra()
{
    if (macdBuffer[1] < 0 && macdBuffer[0] > 0 &&
        rsiBuffer[0] <= 30 &&
        stochKBuffer[0] < 20 && stochDBuffer[0] < stochKBuffer[0] &&
        atrBuffer[0] > ATR_Threshold &&
        adxBuffer[0] > ADX_Threshold &&
        plusDiBuffer[1] < minusDiBuffer[1] && plusDiBuffer[0] > minusDiBuffer[0])
    {
        return true;
    }
    else
    {
        PrintFormat("Falha nas condições de compra: MACD=%.5f, RSI=%.5f, StochK=%.5f, StochD=%.5f, ATR=%.5f, ADX=%.5f, plusDI=%.5f, minusDI=%.5f",
                    macdBuffer[0], rsiBuffer[0], stochKBuffer[0], stochDBuffer[0],
                    atrBuffer[0], adxBuffer[0], plusDiBuffer[0], minusDiBuffer[0]);
        return false;
    }
}

void ExecutaVenda()
{
    double price = SymbolInfoDouble(symbol, SYMBOL_BID);
    double tp = price - TakeProfit * _Point;
    double sl = price + StopLoss * _Point;

    if (!Trade.Sell(LotSize, symbol, price, sl, tp, "Sell Order"))
    {
        Print("Falha ao colocar ordem de venda: ", Trade.ResultRetcodeDescription());
    }
    ResetFlagsVenda();
}

void ExecutaCompra()
{
    double price = SymbolInfoDouble(symbol, SYMBOL_ASK);
    double tp = price + TakeProfit * _Point;
    double sl = price - StopLoss * _Point;

    if (!Trade.Buy(LotSize, symbol, price, sl, tp, "Buy Order"))
    {
        Print("Falha ao colocar ordem de compra: ", Trade.ResultRetcodeDescription());
    }
    ResetFlagsCompra();
}

void ResetFlagsVenda()
{
    dema10_crossed_down = false;
    dema20_crossed_down = false;
}

void ResetFlagsCompra()
{
    dema10_crossed_up = false;
    dema20_crossed_up = false;
}