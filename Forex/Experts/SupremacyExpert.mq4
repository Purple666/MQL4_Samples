//+------------------------------------------------------------------+
//|                                              SupremacyExpert.mq4 |
//|                                                         UncleSam |
//|                                                                  |
//+------------------------------------------------------------------+
#property copyright "UncleSam"
#property link      ""
#property version   "6.00"
#property strict

input int magic = 20181021;
input string currency = "";
input int minTopPercent = 65;
input int tryCount = 5;
input double lots = 0.01;
input int autoMM = 10;
input int sl = 100;
input int slstop = 50;
input int slip = 5;
input int closeTime = 23;
input int closeTimeFriday = 21;
input double closeRealOrdersIfPlusPercent = 25;
input bool dayBar = true;
input bool startAgainst = true;
input bool useReverse = false;
//input bool testInput = false;



const string fileName = "myfxbook";
static int prevtime;
double equityBeginBar;
double equityWithPercent;
double Lots;
bool against;
//+------------------------------------------------------------------+
//| Expert initialization function                                   |
//+------------------------------------------------------------------+
int OnInit()
  {
//---
   prevtime = Time[0];
   commentWindow("Wait next bar...");
   equityBeginBar = AccountEquity();
   equityWithPercent = equityBeginBar + equityBeginBar * closeRealOrdersIfPlusPercent / 100;
   /*int tst = getDataFromHTML();
   Print(tst);*/
   against = startAgainst;
   MathSrand(GetTickCount());
//---
   return(INIT_SUCCEEDED);
  }
//+------------------------------------------------------------------+
//| Expert deinitialization function                                 |
//+------------------------------------------------------------------+
void OnDeinit(const int reason)
  {
//---
   Comment(""); 
  }
//+------------------------------------------------------------------+
//| Expert tick function                                             |
//+------------------------------------------------------------------+
void OnTick()
  {
//---
   datetime timeCur = TimeCurrent();
   //if(OrdersTotalSymb() > 0){
   if(dayBar){
   if(closeTimeFriday > 0 && TimeDayOfWeek(timeCur) == 5 && TimeHour(timeCur) >= closeTimeFriday){
      closeOrders(true);
   }else if(closeTime > 0 && TimeHour(timeCur) >= closeTime){
      closeOrders(true);
   }else if(closeRealOrdersIfPlusPercent > 0 && AccountEquity() >= equityWithPercent){
      closeOrders(true);
      equityBeginBar = AccountEquity();
      equityWithPercent = equityBeginBar + equityBeginBar * closeRealOrdersIfPlusPercent / 100;
      Print(Symbol(),": real orders was closed, because we get profit ",closeRealOrdersIfPlusPercent,"%");
      //Print(Symbol(),": all orders was closed, because we get profit ",closeRealOrdersIfPlusPercent,"%");
   }
   }
   //}

   if(Time[0] != prevtime){
      
      closeOrders(true);
      if(OrdersTotalSymb() == 0){
      
      equityBeginBar = AccountEquity();
      equityWithPercent = equityBeginBar + equityBeginBar * closeRealOrdersIfPlusPercent / 100;
      int oType = getDataFromHTML();
      if(oType != 0){
         Lots = calcLot();
         
         if(oType == -1){ //sell
            double osl=0;
            int spread=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD);
            if(sl>0){
               osl=NormalizeDouble(Ask+sl*Point-spread*Point,Digits);
            }
            RefreshRates();
            int ord1 = openOrder(OP_SELL, Lots, Bid, osl, 0, "SELL", 1); 
            if(ord1 > 0){
               osl=0;
               if(slstop>0){
                  osl=NormalizeDouble(High[1]+slstop*Point,Digits);
               }
               int ord2 = openOrder(OP_SELLLIMIT, Lots, High[1], osl, 0, "SELL LIMIT", 1); 
            }
         }
         
         if(oType == 1){ //buy
            double osl=0;
            int spread=SymbolInfoInteger(Symbol(),SYMBOL_SPREAD);
            if(sl>0){
               osl=NormalizeDouble(Bid-sl*Point+spread*Point,Digits);
            }
            RefreshRates();
            int ord1 = openOrder(OP_BUY, Lots, Ask, osl, 0, "BUY", 1); 
            if(ord1 > 0){
               osl=0;
               if(slstop>0){
                  osl=NormalizeDouble(Low[1]-slstop*Point,Digits);
               }
               int ord2 = openOrder(OP_BUYLIMIT, Lots, Low[1], osl, 0, "BUY LIMIT", 1); 
            }
         }
      
      }
      
      }
      
      prevtime = Time[0];
   }
   
  }
//+------------------------------------------------------------------+

int OrdersTotalSymb(){
   int ot=OrdersTotal();
   int resu=0;

   for(int ii=0; ii<ot; ii++){

      if(OrderSelect(ii, SELECT_BY_POS)==true){
         if(OrderSymbol()== Symbol() && OrderMagicNumber()==magic){
            
            resu++;

         }
      }
   }

   return resu;
}

int openOrder(int t, double l, double p, double ssl, double tp, string tname, int tryNum){
   int res;
   int trC;
   trC = tryNum;
   if(tryNum <= 0){
      trC = 1;   
   }
   
   if(tryNum > tryCount){
   res = 0;
   }else{
   Print(Symbol(), ": Order's opening, try: ", trC);
   
   double prpr = p;
   RefreshRates();
   if(t == OP_SELL){
      prpr = Bid;
   }else if(t == OP_BUY){
      prpr = Ask;
   }
   res = OrderSend(Symbol(), t, l, prpr, slip, ssl, tp, NULL, magic);
   if(res == -1){
      int ee=GetLastError();
      Print(Symbol(), ": Order's opening ",tname,". Error: ", ee);
      trC++;
      int ttt = MathCeil(MathRand() / 6000) * 1000 + 3000;
      Sleep(ttt);
      res = openOrder(t, l, p, ssl, tp, tname, trC);
   }else{
      Print(Symbol(), ": Order ",res," (", tname, ") is open!");
   }
   }
   return res;   
}

void closeOrders(bool withLimit){
   int ot=OrdersTotal();
     
   for(int ii=0; ii<ot; ii++){
      if(OrderSelect(ii, SELECT_BY_POS)==true){

         if(OrderMagicNumber()==magic && OrderSymbol() == Symbol()){
            
            if(OrderType()==OP_SELL){
               RefreshRates();
               double oProfit = OrderProfit();
               bool clsOrder=OrderClose(OrderTicket(),OrderLots(),Ask,slip);
               if(!clsOrder){
                  int ee=GetLastError();
                  Print(Symbol(), ": Error while closing order SELL: ", ee);
               }else{
                  if(useReverse){
                  if(oProfit >= 0){
                     if(against){
                        against = false;
                     }else{
                        against = true;
                     }
                  }else{
                     if(against){
                        against = true;
                     }else{
                        against = false;
                     }
                  }
                  }
               }
            }
            
            if(OrderType()==OP_BUY){
               RefreshRates();
               double oProfit = OrderProfit();
               bool clsOrder=OrderClose(OrderTicket(),OrderLots(),Bid,slip);
               if(!clsOrder){
                  int ee=GetLastError();
                  Print(Symbol(), ": Error while closing order BUY: ", ee);
               }else{
                  if(useReverse){
                  if(oProfit >= 0){
                     if(against){
                        against = false;
                     }else{
                        against = true;
                     }
                  }else{
                     if(against){
                        against = true;
                     }else{
                        against = false;
                     }
                  }
                  }
               }
            }
            
            if(withLimit){
               if(OrderType()==OP_BUYLIMIT || OrderType()==OP_BUYSTOP || OrderType()==OP_SELLLIMIT || OrderType()==OP_SELLSTOP){
                  OrderDelete(OrderTicket());
               }
            }
  
          }
       }
   }
}

double calcLot(){
   double res = 0.01;
   if(autoMM == 0){
      res = lots;
   }else{
      int mm = autoMM;
      if(mm > 100){
         mm = 100;
      }
      double tmpLots = AccountEquity() * mm / 100000;
      res = NormalizeDouble(tmpLots, 2);
      if(res < 0.01){
         res = 0.01;
      }

   }
   return res;
}

int getDataFromHTML(){
   int r = 0;
   string cur = Symbol();
   if(currency != ""){
        cur = currency;   
   }
   string startURL = "http://www.myfxbook.com/community/outlook/";
   string url = StringConcatenate(startURL,cur);
   ResetLastError();
   string cookie=NULL,headers;
   char post[],result[];
   int timeout=5000; //--- timeout менее 1000 (1 сек.) недостаточен при низкой скорости Интернета
   int res=WebRequest("GET",url,cookie,NULL,timeout,post,0,result,headers);
//--- проверка ошибок
   if(res==-1)
   {
      Print(Symbol(), ": Error in WebRequest. Error's code  =",GetLastError());
      //--- возможно, URL отсутствует в списке, выводим сообщение о необходимости его добавления
      Alert(Symbol(), ": You need add address '",startURL,"' in url's list in advisor's settings");
   }
   else
   {
      //--- успешная загрузка
      Print(Symbol(), ": Page is saved on disc, file size =",ArraySize(result)," B");
      //--- сохраняем данные в файл
      string fname = StringConcatenate(fileName, cur, ".txt");
      int filehandle=FileOpen(fname,FILE_WRITE|FILE_BIN);
      //--- проверка ошибки
      if(filehandle!=INVALID_HANDLE)
        {
         //--- сохраняем содержимое массива result[] в файл
         FileWriteArray(filehandle,result,0,ArraySize(result));
         //--- закрываем файл
         FileClose(filehandle);
         
         r = findCurrStr(fname);
        }
      else Print(Symbol(), ": Error in FileOpen. Error's code =",GetLastError());

     }

   
   return r;
}

int findCurrStr(string fn){
   int s = 0;
   
   int file_handle=FileOpen(fn,FILE_READ|FILE_TXT);
   if(file_handle!=INVALID_HANDLE)
   {
      string str;
      int startStrFind = 0;
      string resStr = "";
      while(!FileIsEnding(file_handle)){
         str=FileReadString(file_handle);
         if(StringFind(str, "center paddTD10 dataTable maxWidth") >= 0 && startStrFind == 0){
            startStrFind = 1;
         }
         
         if(startStrFind == 1){
            resStr = StringConcatenate(resStr, StringTrimLeft(StringTrimRight(str)));
         }
         
         if(startStrFind == 1 && StringFind(str, "</table>") >= 0){
            break;
         }

         
      } 
      //Print(resStr);
      if(resStr != ""){
         string tdstr = "<td>Short</td><td>";
         string shortStr = StringSubstr(resStr, StringFind(resStr, tdstr) + StringLen(tdstr), 3);
         if(MathIsValidNumber(StrToInteger(shortStr))){
            int d = StrToInteger(shortStr);
            
            int maxBottomPercent = 100 - minTopPercent;
            string showStr = StringConcatenate(Symbol(), ": percent of short positions ", d, "%.");
            if(d >= minTopPercent && minTopPercent > 50){
               
               if(against){
                  showStr = StringConcatenate(showStr, " BUY!!!");
                  s = 1;
               }else{ //20181025
                  s = -1;  
                  showStr = StringConcatenate(showStr, " SELL!!! (with other)");
               }
               
            }else if(d <= maxBottomPercent && maxBottomPercent >= 0 && maxBottomPercent < 50){
               
               if(against){
                  s = -1;
                  showStr = StringConcatenate(showStr, " SELL!!!");
               }else{ //20181025
                  s = 1; 
                  showStr = StringConcatenate(showStr, " BUY!!! (with other)");
               }
            }else{
               showStr = StringConcatenate(showStr, " Wait next bar...");
            }
            Print(showStr);
            commentWindow(showStr);
         }
      }
      FileClose(file_handle); 
   }else Print(Symbol(), ": Error while opening file ",fn,", error's code = ",GetLastError());
   
   return s;
}

void commentWindow(string strng){
   string divider = "------------------------------";
   Comment("SupremacyExpert\r\n",divider,"\r\n",strng);
}