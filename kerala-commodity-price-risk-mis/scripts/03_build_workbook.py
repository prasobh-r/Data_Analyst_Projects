"""Step 3: build the Excel MIS workbook (formulas, charts, validation) with openpyxl.

Reads build/*.pkl and data/*.csv; writes build/Kerala_Commodity_Price_Risk_MIS_rebuilt.xlsx
(set the MIS_OUT environment variable to choose another path). The committed workbook in the repo root is not touched.
Formulas have no cached values until the file is opened in Excel (or recalculated with LibreOffice)."""
import pandas as pd, numpy as np, re, warnings
from pathlib import Path
ROOT=Path(__file__).resolve().parents[1]
DATA=ROOT/"data"
BUILD=ROOT/"build"; BUILD.mkdir(exist_ok=True)

warnings.filterwarnings('ignore')
from openpyxl import Workbook
from openpyxl.styles import Font, PatternFill, Alignment, Border, Side
from openpyxl.utils import get_column_letter as L
from openpyxl.worksheet.datavalidation import DataValidation
from openpyxl.formatting.rule import CellIsRule, ColorScaleRule, FormulaRule
from openpyxl.chart import BarChart, LineChart, Reference, Series
from openpyxl.chart.shapes import GraphicalProperties
from risk_score import score, W, CAP, TH
U=str(DATA)+'/'
if not (BUILD/'m.pkl').exists():
    raise SystemExit('build/m.pkl not found: run scripts/01_prepare_monthly.py first.')
m=pd.read_pickle(BUILD/'m.pkl'); dpm=pd.read_pickle(BUILD/'dpm.pkl'); md=pd.read_pickle(BUILD/'md.pkl')
sea=pd.read_pickle(BUILD/'sea.pkl'); di=pd.read_pickle(BUILD/'di.pkl'); dd=pd.read_pickle(BUILD/'dd.pkl')
clean=lambda s: re.sub(r'\s+',' ',str(s)).strip()
di['item_name_clean']=di.item_name_clean.map(clean); di['item_group']=di.item_group.map(clean)
di['label']=di.item_name_clean+' ['+di.unit.map(clean)+']'
dpm['item_group']=dpm.item_group.map(clean)
groups=['Cereals','Pulses','Other Food Items','Oil And Oil Seeds','Spices And Condiments','Tubers','Fruits And Vegetables']
assert set(di.item_group)==set(groups), set(di.item_group)
di=di.sort_values('item_id').reset_index(drop=True)
NI=len(di); NM=38
months=list(pd.date_range('2023-01-01','2026-02-01',freq='MS'))
FONT='Arial'
def F(**k): return Font(name=FONT,size=k.pop('size',10),**k)
NAVY='1F3A4D'; TEAL='2E7D6B'; BLUE='2E6F95'; GREY='F2F4F5'
fill=lambda c: PatternFill('solid',start_color=c,end_color=c)
thin=Side(style='thin',color='D0D5D8'); box=Border(left=thin,right=thin,top=thin,bottom=thin)
INP_FONT=F(color='0000FF'); INP_FILL=fill('FFF9DB')
wb=Workbook()
def sheet(name,color=None):
    ws=wb.create_sheet(name); 
    if color: ws.sheet_properties.tabColor=color
    return ws
wb.remove(wb.active)
S={}
for n,c in [('README',NAVY),('Dashboard',NAVY),('Watchlist','C0392B'),('Group_Heatmap','C0392B'),('District_View','C0392B'),('Forecast','C0392B'),
            ('Assumptions','F1C40F'),('Month_View','7F8C8D'),('Chart_Data','7F8C8D'),('Data_Calc','2E6F95'),('Data_District','2E6F95'),
            ('Dim_Item','2E6F95'),('Seasonal','2E6F95'),('Months','2E6F95'),('Lists','2E6F95'),('Data_Quality','27AE60'),('Model_Guide','27AE60')]:
    S[n]=sheet(n,c)
def style_hdr(ws,row,c1,c2,color=NAVY,h=30):
    for c in range(c1,c2+1):
        x=ws.cell(row,c); x.font=F(bold=True,color='FFFFFF'); x.fill=fill(color)
        x.alignment=Alignment(horizontal='center',vertical='center',wrap_text=True); x.border=box
    ws.row_dimensions[row].height=h
def setw(ws,widths):
    for k,v in widths.items(): ws.column_dimensions[k].width=v
def title(ws,text,sub=None):
    ws['A1']=text; ws['A1'].font=F(size=14,bold=True,color=NAVY)
    if sub: ws['A2']=sub; ws['A2'].font=F(size=9,italic=True,color='555555')
# ---------------- Lists / Months / Dim_Item / Seasonal ----------------
ws=S['Months']; 
for j,h in enumerate(['Month idx','Month','Label','Days reported','Last date reported','Scores available?'],1): ws.cell(1,j,h)
style_hdr(ws,1,1,6,BLUE)
mdd=md.set_index('month')
for i,mo in enumerate(months,1):
    r=i+1
    ws.cell(r,1,i); ws.cell(r,2,mo.to_pydatetime()).number_format='mmm yyyy'; ws.cell(r,3,mo.strftime('%b %Y'))
    ws.cell(r,4,int(mdd.loc[mo,'days'])); ws.cell(r,5,mdd.loc[mo,'last'].to_pydatetime()).number_format='dd mmm yyyy'
    ws.cell(r,6,f'=IF(A{r}>=13,"Yes","No (needs 12 months of history)")')
    for c in range(1,7): ws.cell(r,c).font=F()
setw(ws,{'A':10,'B':12,'C':12,'D':14,'E':18,'F':30}); ws.freeze_panes='A2'
MONTH_LIST="Months!$C$14:$C$39"  # idx13..38 -> rows 14..39
ws=S['Dim_Item']
for j,h in enumerate(['item_id','Commodity','Unit','Display label','Group','Months with data (of 38)','Districts reporting'],1): ws.cell(1,j,h)
style_hdr(ws,1,1,7,BLUE)
for i,r_ in di.iterrows():
    r=i+2
    for j,v in enumerate([int(r_.item_id),r_.item_name_clean,clean(r_.unit),r_.label,r_.item_group,int(r_.months_with_data) if pd.notna(r_.months_with_data) else 0,int(r_.districts) if pd.notna(r_.districts) else 0],1):
        ws.cell(r,j,v).font=F()
setw(ws,{'A':9,'B':36,'C':9,'D':42,'E':24,'F':16,'G':14}); ws.freeze_panes='A2'; ws.auto_filter.ref=f'A1:G{NI+1}'
ws=S['Lists']; ws['A1']='Commodity (full 38-month history)'; style_hdr(ws,1,1,1,BLUE)
full_items=di[di.months_with_data>=38].label.tolist()
for i,l in enumerate(full_items,2): ws.cell(i,1,l).font=F()
ws.column_dimensions['A'].width=44
LIST_RNG=f"Lists!$A$2:$A${len(full_items)+1}"
ws=S['Seasonal']
for j,h in enumerate(['item_id','Month no.','Seasonal index (100 = yearly avg)','Key (item*100+month)'],1): ws.cell(1,j,h)
style_hdr(ws,1,1,4,BLUE)
sea=sea.sort_values(['item_id','month']).reset_index(drop=True)
for i,r_ in sea.iterrows():
    r=i+2; ws.cell(r,1,int(r_.item_id)); ws.cell(r,2,int(r_.month)); ws.cell(r,3,float(r_.seasonal_index)); ws.cell(r,4,f'=A{r}*100+B{r}')
    for c in range(1,5): ws.cell(r,c).font=F()
NS=len(sea)+1
setw(ws,{'A':9,'B':10,'C':30,'D':22}); ws.freeze_panes='A2'
# ---------------- Assumptions ----------------
ws=S['Assumptions']; title(ws,'Assumptions & scoring settings','Blue cells on yellow are inputs: change them and every sheet recalculates. All weights and caps are analyst judgement calibrated to this dataset (see README).')
for j,h in enumerate(['Risk component','Weight','Cap: value at which score = 100','What it measures'],1): ws.cell(5,j,h)
style_hdr(ws,5,1,4,NAVY)
comps=[('Price momentum (MoM rise)','mom','Month-on-month price rise of the state average (rises only).'),
('Volatility','vol','Std deviation of the last 12 monthly % changes.'),
('Deviation vs 12M average','dev','Price above its own prior-12-month average (rises only).'),
('Year-on-year change','yoy','Price vs same month last year (rises only). Catches slow, sustained surges.'),
('District dispersion','disp','Coefficient of variation across districts: a supply-stress proxy (uneven availability).'),
('Breadth of rise','brd','Share of reporting districts >10% above their own prior-12M average (statewide vs local).'),
('Seasonal pressure','sea','Seasonal index above 100 for the calendar month (3-year basis: indicative only).')]
for i,(n,k,d) in enumerate(comps):
    r=6+i; ws.cell(r,1,n).font=F()
    c=ws.cell(r,2,W[k]); c.font=INP_FONT; c.fill=INP_FILL; c.number_format='0%'
    c=ws.cell(r,3,CAP[k]); c.font=INP_FONT; c.fill=INP_FILL; c.number_format='0%' if k!='sea' else '0" idx pts"'
    ws.cell(r,4,d).font=F(size=9,color='555555')
ws['A13']='Total weight'; ws['A13'].font=F(bold=True); ws['B13']='=SUM(B6:B12)'; ws['B13'].number_format='0%'; ws['B13'].font=F(bold=True)
ws['C13']='=IF(ROUND(B13,4)=1,"OK: weights sum to 100%","Note: scores are re-scaled by the total weight")'; ws['C13'].font=F(size=9,italic=True)
ws['A15']='Thresholds'; style_hdr(ws,15,1,2,NAVY)
ws['B15']='Value'
th=[('Red alert: risk score at or above',TH['red'],'0'),('Amber: risk score at or above',TH['amber'],'0'),
('High confidence: districts reporting at least',TH['hi'],'0'),('Medium confidence: districts reporting at least (below = excluded)',TH['med'],'0'),
('Sustained surge: YoY change at least',TH['surge'],'0%'),('Sustained surge: also price above 12M average by at least',TH['surgedev'],'0%'),
('Short-term spike: MoM rise at least',TH['spike'],'0%'),('Volatile: 12M volatility at least',TH['volatile'],'0%'),
('Statewide signal: breadth at least',TH['state'],'0%'),('Regional signal: breadth at least',TH['region'],'0%')]
for i,(n,v,fmt) in enumerate(th):
    r=16+i; ws.cell(r,1,n).font=F(); c=ws.cell(r,2,v); c.font=INP_FONT; c.fill=INP_FILL; c.number_format=fmt
ws['A27']='Method notes'; ws['A27'].font=F(bold=True,color=NAVY)
notes=['Risk score (0-100) = weighted average of seven component scores, each = MIN(1, value / cap) x 100, rises only. It measures upward price pressure on consumers.',
'Eligible = month index >= 13 (needs 12 months of history) AND at least the Medium-confidence number of districts reporting. Low-confidence items are excluded from ranking, not scored 0.',
'A state average is the equal-weight mean of district monthly means; a district-month needs at least 5 daily observations to count.',
'Data has prices only (no arrivals, stock or rainfall). "Supply stress" is inferred from dispersion across districts, breadth of rise and seasonality: it is an early-warning indicator, not a shortage forecast.',
'Thresholds, caps and weights were calibrated on the 2024-2026 distribution (caps near the 90th-95th percentile). Change them in the blue cells to test sensitivity.']
for i,t in enumerate(notes): 
    ws.cell(28+i,1,t).font=F(size=9); 
setw(ws,{'A':62,'B':12,'C':32,'D':80})
A=lambda r,c='B': f"Assumptions!${c}${r}"
# ---------------- Data_Calc ----------------
ws=S['Data_Calc']
hdrs=['item_id','Month','Key','Group','Month idx','State avg price','Districts reporting','District dispersion (CV)','Breadth of rise','Seasonal index',
'MoM %','YoY %','12M avg (prior 12)','vs 12M avg %','Volatility (12M)','Confidence','Scored? (1/0)','Score: momentum','Score: volatility','Score: deviation','Score: YoY','Score: dispersion','Score: breadth','Score: seasonal','RISK SCORE','Class','Risk type','Spread signal']
for j,h in enumerate(hdrs,1): ws.cell(1,j,h)
style_hdr(ws,1,1,10,BLUE,45); style_hdr(ws,1,11,28,TEAL,45)
mm=m.sort_values(['item_id','month']).reset_index(drop=True)
assert len(mm)==NI*NM
N=NI*NM+1
for k in range(NI):
    for i in range(1,NM+1):
        r=2+k*NM+(i-1); src=mm.iloc[k*NM+i-1]
        ws.cell(r,1,int(src.item_id)); ws.cell(r,2,src.month.to_pydatetime()).number_format='mmm yyyy'
        ws.cell(r,3,f'=A{r}*1000000+YEAR(B{r})*100+MONTH(B{r})')
        ws.cell(r,4,f'=INDEX(Dim_Item!$E$2:$E${NI+1},MATCH(A{r},Dim_Item!$A$2:$A${NI+1},0))')
        ws.cell(r,5,i)
        for col,key in [(6,'state_avg'),(7,'n_districts'),(8,'disp_cv'),(9,'breadth')]:
            v=src[key]
            if pd.notna(v): ws.cell(r,col,float(v) if col!=7 else int(v))
        ws.cell(r,10,f'=IFERROR(INDEX(Seasonal!$C$2:$C${NS},MATCH(A{r}*100+MONTH(B{r}),Seasonal!$D$2:$D${NS},0)),"")')
        if i>=2: ws.cell(r,11,f'=IF(AND(ISNUMBER(F{r}),ISNUMBER(F{r-1})),F{r}/F{r-1}-1,"")')
        if i>=13:
            ws.cell(r,12,f'=IF(AND(ISNUMBER(F{r}),ISNUMBER(F{r-12})),F{r}/F{r-12}-1,"")')
            ws.cell(r,13,f'=IF(COUNT(F{r-12}:F{r-1})>=8,AVERAGE(F{r-12}:F{r-1}),"")')
            ws.cell(r,14,f'=IF(AND(ISNUMBER(F{r}),ISNUMBER(M{r})),F{r}/M{r}-1,"")')
            ws.cell(r,15,f'=IF(COUNT(K{r-11}:K{r})>=8,STDEV(K{r-11}:K{r}),"")')
        ws.cell(r,16,f'=IF(NOT(ISNUMBER(G{r})),"No data",IF(G{r}>={A(18)},"High",IF(G{r}>={A(19)},"Medium","Low")))')
        ws.cell(r,17,f'=IF(AND(E{r}>=13,ISNUMBER(F{r}),ISNUMBER(K{r}),ISNUMBER(N{r}),ISNUMBER(O{r}),OR(P{r}="High",P{r}="Medium")),1,0)')
        ws.cell(r,18,f'=IF(Q{r}=1,MIN(1,MAX(0,K{r}/{A(6,"C")}))*100,"")')
        ws.cell(r,19,f'=IF(Q{r}=1,MIN(1,O{r}/{A(7,"C")})*100,"")')
        ws.cell(r,20,f'=IF(Q{r}=1,MIN(1,MAX(0,N{r}/{A(8,"C")}))*100,"")')
        ws.cell(r,21,f'=IF(Q{r}=1,MIN(1,MAX(0,IF(ISNUMBER(L{r}),L{r},0)/{A(9,"C")}))*100,"")')
        ws.cell(r,22,f'=IF(Q{r}=1,MIN(1,IF(ISNUMBER(H{r}),H{r},0)/{A(10,"C")})*100,"")')
        ws.cell(r,23,f'=IF(Q{r}=1,MIN(1,IF(ISNUMBER(I{r}),I{r},0)/{A(11,"C")})*100,"")')
        ws.cell(r,24,f'=IF(Q{r}=1,MIN(1,MAX(0,(IF(ISNUMBER(J{r}),J{r},100)-100)/{A(12,"C")}))*100,"")')
        ws.cell(r,25,f'=IF(Q{r}=1,({A(6)}*R{r}+{A(7)}*S{r}+{A(8)}*T{r}+{A(9)}*U{r}+{A(10)}*V{r}+{A(11)}*W{r}+{A(12)}*X{r})/{A(13)},"")')
        ws.cell(r,26,f'=IF(Q{r}=1,IF(Y{r}>={A(16)},"Red",IF(Y{r}>={A(17)},"Amber","Green")),IF(AND(E{r}>=13,P{r}="Low"),"Low data",""))')
        ws.cell(r,27,f'=IF(Q{r}=1,IF(AND(ISNUMBER(L{r}),L{r}>={A(20)},N{r}>={A(21)}),"Sustained surge",IF(K{r}>={A(22)},"Short-term spike",IF(O{r}>={A(23)},"Volatile","Stable"))),"")')
        ws.cell(r,28,f'=IF(Q{r}=1,IF(AND(ISNUMBER(I{r}),I{r}>={A(24)}),"Statewide",IF(AND(ISNUMBER(I{r}),I{r}>={A(25)}),"Regional","Isolated/none")),"")')
fm={6:'#,##0.00',8:'0.0%',9:'0%',10:'0.0',11:'0.0%',12:'0.0%',13:'#,##0.00',14:'0.0%',15:'0.0%',25:'0.0'}
for c in range(18,25): fm[c]='0.0'
for r in range(2,N+1):
    for c in range(1,29):
        x=ws.cell(r,c); x.font=F(size=9)
        if c in fm: x.number_format=fm[c]
ws.freeze_panes='D2'; ws.auto_filter.ref=f'A1:AB{N}'
setw(ws,{L(c):13 for c in range(1,29)}); ws.column_dimensions['D'].width=22
ws.conditional_formatting.add(f'Z2:Z{N}',CellIsRule(operator='equal',formula=['"Red"'],fill=fill('F8CBCB'),font=Font(name=FONT,size=9,color='9C0006')))
ws.conditional_formatting.add(f'Z2:Z{N}',CellIsRule(operator='equal',formula=['"Amber"'],fill=fill('FFE8B3'),font=Font(name=FONT,size=9,color='7F5200')))
ws.conditional_formatting.add(f'Z2:Z{N}',CellIsRule(operator='equal',formula=['"Green"'],fill=fill('D5F0DC'),font=Font(name=FONT,size=9,color='1B5E20')))
DC=lambda col: f"Data_Calc!${col}$2:${col}${N}"
# ---------------- Data_District ----------------
ws=S['Data_District']
for j,h in enumerate(['district_id','District','item_id','Group','Month','District avg price','State avg price','Premium vs state avg','Eligible (1/0)','Districts reporting (item-month)'],1): ws.cell(1,j,h)
style_hdr(ws,1,1,7,BLUE,40); style_hdr(ws,1,8,9,TEAL,40); style_hdr(ws,1,10,10,BLUE,40)
dp=dpm.sort_values(['district_id','item_id','month']).reset_index(drop=True)
ND=len(dp)+1
for i,r_ in dp.iterrows():
    r=i+2
    ws.cell(r,1,int(r_.district_id)); ws.cell(r,2,r_.district_name); ws.cell(r,3,int(r_.item_id)); ws.cell(r,4,r_.item_group)
    ws.cell(r,5,r_.month.to_pydatetime()); ws.cell(r,6,float(r_.d_avg)); ws.cell(r,7,float(r_.state_avg))
    ws.cell(r,8,f'=F{r}/G{r}-1'); ws.cell(r,9,f'=IF(J{r}>={A(19)},1,0)'); ws.cell(r,10,int(r_.n_districts))
for r in range(2,ND+1):
    ws.cell(r,5).number_format='mmm yyyy'; ws.cell(r,6).number_format='#,##0.00'; ws.cell(r,7).number_format='#,##0.00'; ws.cell(r,8).number_format='0.0%'
ws.freeze_panes='A2'; ws.auto_filter.ref=f'A1:J{ND}'
setw(ws,{'A':10,'B':20,'C':9,'D':22,'E':11,'F':14,'G':14,'H':14,'I':11,'J':16})
DD=lambda col: f"Data_District!${col}$2:${col}${ND}"
# ---------------- Month_View ----------------
ws=S['Month_View']; title(ws,'Month view (helper): all commodities for the month selected on the Dashboard')
ws['A3']='Selected label'; ws['B3']='=Dashboard!$C$4'
ws['A4']='Selected month'; ws['B4']=f'=INDEX(Months!$B$2:$B$39,MATCH(Dashboard!$C$4,Months!$C$2:$C$39,0))'; ws['B4'].number_format='mmm yyyy'
ws['D3']='Key (yyyymm)'; ws['E3']='=YEAR(B4)*100+MONTH(B4)'
mv=['item_id','Commodity','Group','Data_Calc row','Price','MoM %','YoY %','vs 12M avg %','Volatility','Districts','Confidence','Risk score','Class','Risk type','Spread signal','Scored?','Score (rounded)','Risk rank','MoM (scored)','MoM rank: rises','MoM rank: falls']
for j,h in enumerate(mv,1): ws.cell(6,j,h)
style_hdr(ws,6,1,len(mv),NAVY,32)
pull={5:'F',6:'K',7:'L',8:'N',9:'O',10:'G',11:'P',12:'Y',13:'Z',14:'AA',15:'AB'}
R0,R1=7,6+NI
for k in range(NI):
    r=7+k; d=k+2
    ws.cell(r,1,f'=Dim_Item!A{d}'); ws.cell(r,2,f'=Dim_Item!D{d}'); ws.cell(r,3,f'=Dim_Item!E{d}')
    ws.cell(r,4,f'=MATCH(A{r}*1000000+$E$3,{DC("C")},0)')
    for c,col in pull.items():
        ws.cell(r,c,f'=IF(INDEX({DC(col)},$D{r})="","",INDEX({DC(col)},$D{r}))')
    ws.cell(r,16,f'=IF(ISNUMBER(L{r}),1,0)')
    ws.cell(r,17,f'=IF(P{r}=1,ROUND(L{r},4),"")')
    ws.cell(r,18,f'=IF(P{r}=1,COUNTIF($Q${R0}:$Q${R1},">"&Q{r})+COUNTIF($Q${R0}:Q{r},Q{r}),"")')
    ws.cell(r,19,f'=IF(AND(P{r}=1,ISNUMBER(F{r})),ROUND(F{r},6),"")')
    ws.cell(r,20,f'=IF(S{r}="","",COUNTIF($S${R0}:$S${R1},">"&S{r})+COUNTIF($S${R0}:S{r},S{r}))')
    ws.cell(r,21,f'=IF(S{r}="","",COUNTIF($S${R0}:$S${R1},"<"&S{r})+COUNTIF($S${R0}:S{r},S{r}))')
    for c in range(1,22):
        x=ws.cell(r,c); x.font=F(size=9)
    for c,fmt in {5:'#,##0.00',6:'0.0%',7:'0.0%',8:'0.0%',9:'0.0%',12:'0.0',17:'0.0000',19:'0.0000'}.items(): ws.cell(r,c).number_format=fmt
setw(ws,{L(c):13 for c in range(1,22)}); ws.column_dimensions['B'].width=40; ws.column_dimensions['C'].width=22
ws.freeze_panes='C7'
MV=lambda col: f"Month_View!${col}${R0}:${col}${R1}"
for cond,(bg,fg) in {'Red':('F8CBCB','9C0006'),'Amber':('FFE8B3','7F5200'),'Green':('D5F0DC','1B5E20')}.items():
    ws.conditional_formatting.add(f'M{R0}:M{R1}',CellIsRule(operator='equal',formula=[f'"{cond}"'],fill=fill(bg),font=Font(name=FONT,size=9,color=fg)))
# ---------------- Watchlist ----------------
ws=S['Watchlist']; title(ws,'MIS exception report: Top 15 price-risk alerts','Month and thresholds are set on Dashboard / Assumptions. Ranked by risk score; low-confidence commodities are excluded.')
ws['A3']='Month:'; ws['B3']='=Dashboard!$C$4'; ws['A3'].font=F(bold=True); ws['B3'].font=F(bold=True,color='C0392B')
wh=['Rank','Commodity','Group','Price (per unit)','MoM %','YoY %','vs 12M avg','Volatility','Risk score','Class','Risk type','Spread signal','Districts reporting','Suggested action','row idx','item_id']
for j,h in enumerate(wh,1): ws.cell(5,j,h)
style_hdr(ws,5,1,16,NAVY,32)
def act(r): return (f'=IF($O{r}="","",IF(K{r}="Sustained surge","Price level has reset: review budgets/contracts, check substitutes, monitor monthly",'
 f'IF(K{r}="Short-term spike","Spike: check market reports, delay non-urgent purchases, review again in 2 weeks",'
 f'IF(K{r}="Volatile","Volatile: set price alert band, avoid large forward purchases, track weekly",'
 f'IF(J{r}="Red","Red alert: escalate and review sourcing options","Monitor in next monthly review")))))')
for n in range(1,16):
    r=5+n; ws.cell(r,1,n)
    ws.cell(r,15,f'=IFERROR(MATCH(A{r},{MV("R")},0),"")')
    src={2:'B',3:'C',4:'E',5:'F',6:'G',7:'H',8:'I',9:'L',10:'M',11:'N',12:'O',13:'J',16:'A'}
    for c,col in src.items():
        ws.cell(r,c,f'=IF($O{r}="","",INDEX({MV(col)},$O{r}))')
    ws.cell(r,14,act(r))
    for c in range(1,17): ws.cell(r,c).font=F(size=9 if c==14 else 10); ws.cell(r,c).border=box
    for c,fmt in {4:'#,##0.00',5:'+0.0%;-0.0%;0.0%',6:'+0.0%;-0.0%;0.0%',7:'+0.0%;-0.0%;0.0%',8:'0.0%',9:'0.0'}.items(): ws.cell(r,c).number_format=fmt
ws['A22']='Biggest monthly movers (scored commodities)'; ws['A22'].font=F(bold=True,color=NAVY,size=11)
for j,h in enumerate(['Rank','Largest rises','Group','Price','MoM %','YoY %','Class'],1): ws.cell(23,j,h)
style_hdr(ws,23,1,7,TEAL,24)
for j,h in enumerate(['Rank','Largest falls','Group','Price','MoM %','YoY %','Class'],1): ws.cell(31,j,h)
style_hdr(ws,31,1,7,TEAL,24)
for blk,(r0,rk) in {'rise':(24,'T'),'fall':(32,'U')}.items():
    for n in range(1,6):
        r=r0+n-1; ws.cell(r,1,n)
        idx=f'IFERROR(MATCH($A{r},{MV(rk)},0),"")'
        for c,col in {2:'B',3:'C',4:'E',5:'F',6:'G',7:'M'}.items():
            ws.cell(r,c,f'=IFERROR(INDEX({MV(col)},{idx}),"")')
        for c in range(1,8): ws.cell(r,c).font=F(); ws.cell(r,c).border=box
        ws.cell(r,4).number_format='#,##0.00'; ws.cell(r,5).number_format='+0.0%;-0.0%;0.0%'; ws.cell(r,6).number_format='+0.0%;-0.0%;0.0%'
setw(ws,{'A':7,'B':38,'C':22,'D':13,'E':10,'F':10,'G':11,'H':10,'I':10,'J':9,'K':17,'L':14,'M':12,'N':70,'O':8,'P':8})
for rng in ['J6:J20','G24:G28','G32:G36']:
    for cond,(bg,fg) in {'Red':('F8CBCB','9C0006'),'Amber':('FFE8B3','7F5200'),'Green':('D5F0DC','1B5E20')}.items():
        ws.conditional_formatting.add(rng,CellIsRule(operator='equal',formula=[f'"{cond}"'],fill=fill(bg),font=Font(name=FONT,color=fg)))
ws.conditional_formatting.add('I6:I20',ColorScaleRule(start_type='num',start_value=0,start_color='FFFFFF',end_type='num',end_value=100,end_color='F4A6A6'))
ws.freeze_panes='C6'
# ---------------- Group_Heatmap ----------------
ws=S['Group_Heatmap']; title(ws,'Risk heatmaps: last 12 months to the selected month','Average risk score of scored commodities by group, and month-by-month risk for today\'s Top 15. Colours: green low, amber moderate, red high.')
ws['A4']='Average risk score by commodity group'; ws['A4'].font=F(bold=True,color=NAVY,size=11)
ws.cell(5,1,'Group'); 
for k in range(12): ws.cell(5,3+k,f'=EDATE(Month_View!$B$4,{-(11-k)})').number_format='mmm yy'
ws.cell(5,2,'Scored items (selected month)')
style_hdr(ws,5,1,14,NAVY,32)
for i,g in enumerate(groups+['All scored commodities']):
    r=6+i; ws.cell(r,1,g).font=F(bold=(i==7))
    if i<7: ws.cell(r,2,f'=COUNTIFS({MV("C")},A{r},{MV("P")},1)')
    else: ws.cell(r,2,f'=SUM({MV("P")})')
    for k in range(12):
        c=3+k; col=L(c)
        if i<7: f_=f'=IFERROR(AVERAGEIFS({DC("Y")},{DC("D")},$A{r},{DC("B")},{col}$5,{DC("Q")},1),"")'
        else: f_=f'=IFERROR(AVERAGEIFS({DC("Y")},{DC("B")},{col}$5,{DC("Q")},1),"")'
        x=ws.cell(r,c,f_); x.number_format='0.0'; x.alignment=Alignment(horizontal='center')
    for c in range(1,15): ws.cell(r,c).font=F(bold=(i==7)); ws.cell(r,c).border=box
ws['A16']="Top 15 commodities this month: risk score over the last 12 months"; ws['A16'].font=F(bold=True,color=NAVY,size=11)
ws.cell(17,1,'Commodity'); ws.cell(17,2,'item_id')
for k in range(12): ws.cell(17,3+k,f'={L(3+k)}5').number_format='mmm yy'
style_hdr(ws,17,1,14,NAVY,32)
for n in range(15):
    r=18+n; ws.cell(r,1,f'=Watchlist!B{6+n}'); ws.cell(r,2,f'=Watchlist!P{6+n}')
    for k in range(12):
        col=L(3+k)
        key=f'$B{r}*1000000+YEAR({col}$17)*100+MONTH({col}$17)'
        ws.cell(r,3+k,f'=IF($B{r}="","",IFERROR(IF(INDEX({DC("Y")},MATCH({key},{DC("C")},0))="","",INDEX({DC("Y")},MATCH({key},{DC("C")},0))),""))').number_format='0.0'
        ws.cell(r,3+k).alignment=Alignment(horizontal='center')
    for c in range(1,15): ws.cell(r,c).font=F(); ws.cell(r,c).border=box
cs=ColorScaleRule(start_type='num',start_value=15,start_color='63BE7B',mid_type='num',mid_value=40,mid_color='FFEB84',end_type='num',end_value=75,end_color='F8696B')
ws.conditional_formatting.add('C6:N13',cs); ws.conditional_formatting.add('C18:N32',cs)
setw(ws,{'A':40,'B':14}); 
for c in range(3,15): ws.column_dimensions[L(c)].width=9
ws.freeze_panes='C6'
# ---------------- District_View ----------------
ws=S['District_View']; title(ws,'District price premium vs state average: selected month','Average % by which each district\'s price is above (+) or below (-) the state average, by commodity group (scored-confidence items only). Red = pricier district.')
ws['A3']='Month:'; ws['B3']='=Dashboard!$C$4'; ws['A3'].font=F(bold=True); ws['B3'].font=F(bold=True,color='C0392B')
ws.cell(5,1,'District'); ws.cell(5,2,'district_id')
for j,g in enumerate(groups): ws.cell(5,3+j,g)
ws.cell(5,10,'All groups'); ws.cell(5,11,'Rank (1 = priciest)')
style_hdr(ws,5,1,11,NAVY,34)
dds=dd.sort_values('district_id').reset_index(drop=True)
for i,r_ in dds.iterrows():
    r=6+i; ws.cell(r,1,r_.district_name); ws.cell(r,2,int(r_.district_id))
    for j in range(7):
        col=L(3+j)
        ws.cell(r,3+j,f'=IFERROR(AVERAGEIFS({DD("H")},{DD("A")},$B{r},{DD("D")},{col}$5,{DD("E")},Month_View!$B$4,{DD("I")},1),"")')
    ws.cell(r,10,f'=IFERROR(AVERAGEIFS({DD("H")},{DD("A")},$B{r},{DD("E")},Month_View!$B$4,{DD("I")},1),"")')
    ws.cell(r,11,f'=IF(ISNUMBER(J{r}),RANK(J{r},$J$6:$J$19,0),"")')
    for c in range(1,12):
        ws.cell(r,c).font=F(); ws.cell(r,c).border=box
        if 3<=c<=10: ws.cell(r,c).number_format='+0.0%;-0.0%;0.0%'; ws.cell(r,c).alignment=Alignment(horizontal='center')
ws.conditional_formatting.add('C6:J19',ColorScaleRule(start_type='num',start_value=-0.12,start_color='63BE7B',mid_type='num',mid_value=0,mid_color='FFFFFF',end_type='num',end_value=0.12,end_color='F8696B'))
setw(ws,{'A':22,'B':11,'C':12,'D':12,'E':14,'F':16,'G':16,'H':12,'I':16,'J':12,'K':16})
ws['A21']='Note: premium compares each district\'s monthly mean to the equal-weight state mean of districts reporting that item; items with fewer than the Medium-confidence number of districts are excluded.'; ws['A21'].font=F(size=9,italic=True)
# ---------------- Forecast ----------------
ws=S['Forecast']; title(ws,'Forecast scenarios (indicative, not backtested)','Forecasts supplied with the dataset (90 days from 28 Feb 2026). Actuals = mean across districts per day; days with fewer than 10 districts reporting are excluded from the actual series.')
fact=pd.read_csv(U+'fact_daily_prices_clean.csv').merge(pd.read_csv(U+'dim_date.csv',parse_dates=['full_date'])[['date_id','full_date']],on='date_id')
fitems=[('Tomato',48,'forecast_Tomato.csv'),('Ladies Finger',40,'forecast_Ladies_Finger.csv'),('Coconut oil (Kera)',54,'forecast_Coconut_oil_Kera.csv')]
DS=35; NA_=90; NF=90
blocks=[]
for bi,(nm,iid,fn) in enumerate(fitems):
    c0=1+bi*6
    d=fact[fact.item_id==iid].groupby('full_date').price.agg(['mean','size']); d=d[d['size']>=10]['mean'].tail(NA_)
    fc=pd.read_csv(U+fn,parse_dates=['date'])
    ws.cell(DS-2,c0,nm).font=F(bold=True,color=NAVY,size=11)
    for j,h in enumerate(['Date','Actual (state avg)','Forecast','Lower bound','Upper bound']): ws.cell(DS-1,c0+j,h)
    style_hdr(ws,DS-1,c0,c0+4,TEAL,32)
    for i,(dt_,v) in enumerate(d.items()):
        r=DS+i; ws.cell(r,c0,dt_.to_pydatetime()).number_format='dd mmm yy'; ws.cell(r,c0+1,float(v)).number_format='#,##0.0'
    for i,rr in fc.reset_index(drop=True).iterrows():
        r=DS+NA_+i; ws.cell(r,c0,rr.date.to_pydatetime()).number_format='dd mmm yy'
        for j,k in enumerate(['predicted_price','lower_bound','upper_bound']): ws.cell(r,c0+2+j,float(rr[k])).number_format='#,##0.0'
    for r in range(DS,DS+NA_+NF):
        for j in range(5): ws.cell(r,c0+j).font=F(size=9)
    blocks.append(c0)
ws['A4']='Sanity checks'; ws['A4'].font=F(bold=True,color=NAVY,size=11)
ws.cell(5,1,'Check'); 
for bi,(nm,_,_) in enumerate(fitems): ws.cell(5,2+bi,nm)
style_hdr(ws,5,1,4,NAVY,24)
labels=['Last 30 actual obs: average','First forecast value','Gap: first forecast vs last-30 avg','Average forecast over 90 days','Band width at day 90 (% of forecast)','Status']
for i,l in enumerate(labels): ws.cell(6+i,1,l).font=F()
a0=DS+NA_-30; a1=DS+NA_-1; f0=DS+NA_; f1=DS+NA_+NF-1
for bi,c0 in enumerate(blocks):
    cc=2+bi; A_=L(c0+1); Fc=L(c0+2); Lo=L(c0+3); Up=L(c0+4)
    ws.cell(6,cc,f'=AVERAGE({A_}{a0}:{A_}{a1})').number_format='#,##0.0'
    ws.cell(7,cc,f'={Fc}{f0}').number_format='#,##0.0'
    ws.cell(8,cc,f'={L(cc)}7/{L(cc)}6-1').number_format='+0.0%;-0.0%'
    ws.cell(9,cc,f'=AVERAGE({Fc}{f0}:{Fc}{f1})').number_format='#,##0.0'
    ws.cell(10,cc,f'=({Up}{f1}-{Lo}{f1})/{Fc}{f1}').number_format='0%'
    ws.cell(11,cc,f'=IF(ABS({L(cc)}8)>0.15,"Check: large jump at forecast start",IF({L(cc)}10>0.5,"Wide band: low confidence","OK"))')
    for r in range(6,12): ws.cell(r,cc).font=F(); ws.cell(r,cc).border=box
for r in range(6,12): ws.cell(r,1).border=box
ws['F4']='Method of the supplied forecasts is not documented in the dataset. Treat as scenarios; run a hold-out backtest (e.g. last 90 days) and report MAPE before presenting them as predictions.'; ws['F4'].font=F(size=9,italic=True,color='C0392B')
for bi,c0 in enumerate(blocks):
    ch=LineChart(); ch.title=fitems[bi][0]+': actual vs forecast'; ch.height=7; ch.width=11.5
    for j,(nm,col) in enumerate([('Actual',c0+1),('Forecast',c0+2),('Lower',c0+3),('Upper',c0+4)]):
        s=Series(Reference(ws,min_col=col,min_row=DS-1,max_row=DS+NA_+NF-1),title_from_data=True); 
        s.smooth=False; s.marker.symbol='none'
        s.graphicalProperties.line.width=19000 if j<2 else 9000
        s.graphicalProperties.line.solidFill=['2E6F95','C0392B','AAB7B8','AAB7B8'][j]
        if j>=2: s.graphicalProperties.line.dashStyle='dash'
        ch.series.append(s)
    ch.set_categories(Reference(ws,min_col=c0,min_row=DS,max_row=DS+NA_+NF-1))
    ch.x_axis.number_format='mmm yy'; ch.x_axis.tickLblSkip=30; ch.x_axis.delete=False; ch.y_axis.delete=False; ch.legend.position='b'
    ws.add_chart(ch,f'{L(1+bi*6)}13' if bi==0 else f'{L(1+bi*6)}13')
setw(ws,{'A':36,'B':16,'C':16,'D':18,'E':14,'F':13,'G':13,'H':16,'I':13,'J':13,'K':13,'L':13,'M':13,'N':16,'O':13,'P':13,'Q':13})
# ---------------- Chart_Data ----------------
ws=S['Chart_Data']; title(ws,'Chart data (helper ranges for Dashboard charts)')
ws['A3']='Top 10 risk scores'; ws['A3'].font=F(bold=True)
for n in range(10): ws.cell(4+n,1,f'=Watchlist!B{6+n}'); ws.cell(4+n,2,f'=Watchlist!I{6+n}')
ws['E3']='Selected commodity'; ws['E3'].font=F(bold=True); ws['F3']='=Dashboard!$G$4'
ws['E4']='item_id'; ws['F4']=f'=INDEX(Dim_Item!$A$2:$A${NI+1},MATCH(Dashboard!$G$4,Dim_Item!$D$2:$D${NI+1},0))'
for j,h in enumerate(['Month','Price','12M avg (prior)','Risk score'],5): ws.cell(5,j,h)
style_hdr(ws,5,5,8,BLUE,24)
for i in range(1,NM+1):
    r=5+i; ws.cell(r,5,f'=Months!B{i+1}').number_format='mmm yy'
    key=f'$F$4*1000000+YEAR(E{r})*100+MONTH(E{r})'
    for c,col in [(6,'F'),(7,'M'),(8,'Y')]:
        ws.cell(r,c,f'=IFERROR(IF(INDEX({DC(col)},MATCH({key},{DC("C")},0))="","",INDEX({DC(col)},MATCH({key},{DC("C")},0))),"")')
    ws.cell(r,6).number_format='#,##0.00'; ws.cell(r,7).number_format='#,##0.00'; ws.cell(r,8).number_format='0.0'
CH0,CH1=5+13,5+NM  # months idx13..38 -> rows 18..43
ws['J3']='Class counts by group (selected month)'; ws['J3'].font=F(bold=True)
for j,h in enumerate(['Group','Red','Amber','Green','Low data'],10): ws.cell(5,j,h)
style_hdr(ws,5,10,14,BLUE,24)
for i,g in enumerate(groups):
    r=6+i; ws.cell(r,10,g)
    for j,cl in enumerate(['Red','Amber','Green','Low data']):
        ws.cell(r,11+j,f'=COUNTIFS({MV("C")},$J{r},{MV("M")},"{cl}")')
setw(ws,{'A':40,'B':10,'E':12,'F':14,'G':14,'H':12,'J':24})
for row in ws.iter_rows(min_row=4,max_row=44):
    for x in row:
        if x.font.name!=FONT or x.font.bold is not True: x.font=F(size=9,bold=x.font.bold,color=x.font.color)
# ---------------- Dashboard ----------------
ws=S['Dashboard']; ws.sheet_view.showGridLines=False
for c in range(1,16): ws.column_dimensions[L(c)].width=12.5
ws.column_dimensions['A'].width=2
ws.column_dimensions['C'].width=16; ws.column_dimensions['D'].width=16
ws.merge_cells('B2:N2'); ws['B2']='Kerala Essential Commodities: Price & Supply-Stress Intelligence'; ws['B2'].font=F(size=18,bold=True,color='FFFFFF'); ws['B2'].fill=fill(NAVY); ws['B2'].alignment=Alignment(vertical='center',indent=1)
ws.row_dimensions[2].height=36
ws.merge_cells('B3:N3'); ws['B3']='Monthly MIS dashboard | 14 districts, 72 commodities, daily retail prices Jan 2023 - Feb 2026 | Price-risk early warning (no arrivals/stock data)'; ws['B3'].font=F(size=9,italic=True,color='555555')
ws['B4']='Select month'; ws['B4'].font=F(bold=True)
ws.merge_cells('C4:D4'); ws['C4']='Feb 2026'; 
for c in ('C4','D4','G4','H4','I4','J4','K4'): ws[c].fill=INP_FILL; ws[c].border=box
ws['C4'].font=F(bold=True,color='0000FF',size=11)
ws['F4']='Commodity trend'; ws['F4'].font=F(bold=True); ws['F4'].alignment=Alignment(horizontal='right')
ws.merge_cells('G4:K4'); ws['G4']='Tomato [Kg]'; ws['G4'].font=F(bold=True,color='0000FF',size=11)
ws['L4']='Data through:'; ws['L4'].font=F(bold=True); ws['L4'].alignment=Alignment(horizontal='right')
ws['M4']='=INDEX(Months!$E$2:$E$39,MATCH($C$4,Months!$C$2:$C$39,0))'; ws['M4'].number_format='dd mmm yyyy'; ws['M4'].font=F(bold=True)
dv=DataValidation(type='list',formula1='='+MONTH_LIST,allow_blank=False); dv.add('C4'); ws.add_data_validation(dv)
dv2=DataValidation(type='list',formula1='='+LIST_RNG,allow_blank=False); dv2.add('G4'); ws.add_data_validation(dv2)
cards=[('B','C','RED ALERTS',f'=COUNTIF({MV("M")},"Red")','0','=" of "&SUM('+MV("P")+')&" scored commodities"','F8CBCB','9C0006'),
('D','E','AMBER WATCH',f'=COUNTIF({MV("M")},"Amber")','0','="score "&'+A(17)+'&" to below "&'+A(16),'FFE8B3','7F5200'),
('F','G','HIGHEST RISK',f'=IFERROR(TEXT(INDEX({MV("L")},MATCH(1,{MV("R")},0)),"0"),"-")','@',f'=IFERROR(INDEX({MV("B")},MATCH(1,{MV("R")},0)),"")','FDEDEC','9C0006'),
('H','I','LARGEST MoM RISE',f'=IFERROR(INDEX({MV("F")},MATCH(1,{MV("T")},0)),"-")','+0.0%;-0.0%',f'=IFERROR(INDEX({MV("B")},MATCH(1,{MV("T")},0)),"")','EAF2F8','1F3A4D'),
('J','K','STATEWIDE SPREAD',f'=COUNTIFS({MV("O")},"Statewide",{MV("P")},1)','0','="commodities rising across >="&TEXT('+A(24)+',"0%")&" of districts"','EAF2F8','1F3A4D'),
('L','M','AVG RISK SCORE',f'=IFERROR(AVERAGE({MV("L")}),"-")','0.0','="across scored commodities"','EAF2F8','1F3A4D')]
for c1,c2,lab,val,fmt,sub,bg,fg in cards:
    for r in (6,7,8):
        ws.merge_cells(f'{c1}{r}:{c2}{r}')
        for c in (c1,c2): ws[f'{c}{r}'].fill=fill(bg)
    ws[f'{c1}6']=lab; ws[f'{c1}6'].font=F(size=8,bold=True,color='555555'); ws[f'{c1}6'].alignment=Alignment(horizontal='center')
    ws[f'{c1}7']=val; ws[f'{c1}7'].font=F(size=20,bold=True,color=fg); ws[f'{c1}7'].alignment=Alignment(horizontal='center',vertical='center'); ws[f'{c1}7'].number_format=fmt
    ws[f'{c1}8']=sub; ws[f'{c1}8'].font=F(size=8,color='555555'); ws[f'{c1}8'].alignment=Alignment(horizontal='center',wrap_text=True,vertical='top')
ws.row_dimensions[7].height=34; ws.row_dimensions[8].height=26
ws['B10']='Top 10 price-risk alerts'; ws['B10'].font=F(size=12,bold=True,color=NAVY)
hd=[('B',None,'Rank'),('C','D','Commodity'),('E','F','Group'),('G',None,'Price'),('H',None,'MoM'),('I',None,'YoY'),('J',None,'Score'),('K',None,'Class'),('L','M','Risk type'),('N',None,'Spread')]
for a,b,t in hd:
    if b: ws.merge_cells(f'{a}11:{b}11')
    ws[f'{a}11']=t
for c in range(2,15):
    x=ws.cell(11,c); x.font=F(bold=True,color='FFFFFF'); x.fill=fill(NAVY); x.alignment=Alignment(horizontal='center')
wsrc={'B':'A','C':'B','E':'C','G':'D','H':'E','I':'F','J':'I','K':'J','L':'K','N':'L'}
for n in range(10):
    r=12+n
    for a,b,t in hd:
        if b: ws.merge_cells(f'{a}{r}:{b}{r}')
        ws[f'{a}{r}']=f'=Watchlist!{wsrc[a]}{6+n}'
    for c in range(2,15): ws.cell(r,c).font=F(size=9); ws.cell(r,c).border=box; ws.cell(r,c).alignment=Alignment(horizontal='center' if c not in (3,5) else 'left')
    ws[f'G{r}'].number_format='#,##0.00'; ws[f'H{r}'].number_format='+0.0%;-0.0%;0.0%'; ws[f'I{r}'].number_format='+0.0%;-0.0%;0.0%'; ws[f'J{r}'].number_format='0.0'
for cond,(bg,fg) in {'Red':('F8CBCB','9C0006'),'Amber':('FFE8B3','7F5200'),'Green':('D5F0DC','1B5E20')}.items():
    ws.conditional_formatting.add('K12:K21',CellIsRule(operator='equal',formula=[f'"{cond}"'],fill=fill(bg),font=Font(name=FONT,bold=True,color=fg)))
ws.conditional_formatting.add('J12:J21',ColorScaleRule(start_type='num',start_value=0,start_color='FFFFFF',end_type='num',end_value=100,end_color='F4A6A6'))
ws['B22']='Low-confidence commodities (fewer districts reporting than the Medium threshold) are excluded from ranking. Change thresholds on the Assumptions sheet.'; ws['B22'].font=F(size=8,italic=True,color='777777')
# charts
b1=BarChart(); b1.type='bar'; b1.title='Top 10 risk scores'; b1.height=7.5; b1.width=14.5; b1.legend=None
b1.add_data(Reference(S['Chart_Data'],min_col=2,min_row=4,max_row=13),titles_from_data=False)
b1.set_categories(Reference(S['Chart_Data'],min_col=1,min_row=4,max_row=13))
b1.x_axis.scaling.orientation='maxMin'; b1.y_axis.scaling.min=0; b1.y_axis.scaling.max=100; b1.x_axis.delete=False; b1.y_axis.delete=False
b1.series[0].graphicalProperties.solidFill='C0392B'; b1.gapWidth=60
ws.add_chart(b1,'B24')
l2=LineChart(); l2.title='Selected commodity: price vs prior 12M average'; l2.height=7.5; l2.width=14.5
cd=S['Chart_Data']
for col,colr in [(6,'2E6F95'),(7,'E67E22')]:
    s=Series(Reference(cd,min_col=col,min_row=CH0,max_row=CH1),title=['Price','12M avg (prior)'][col-6]); s.smooth=False; s.marker.symbol='none'
    s.graphicalProperties.line.solidFill=colr; s.graphicalProperties.line.width=22000; l2.series.append(s)
l2.set_categories(Reference(cd,min_col=5,min_row=CH0,max_row=CH1)); l2.x_axis.number_format='mmm yy'; l2.x_axis.delete=False; l2.y_axis.delete=False; l2.legend.position='b'; l2.x_axis.tickLblSkip=3
ws.add_chart(l2,'H24')
b3=BarChart(); b3.type='bar'; b3.grouping='stacked'; b3.overlap=100; b3.title='Alert class by commodity group'; b3.height=7.5; b3.width=14.5
for col,colr in [(11,'C0392B'),(12,'F39C12'),(13,'27AE60')]:
    s=Series(Reference(cd,min_col=col,min_row=6,max_row=12),title=cd.cell(5,col).value); s.graphicalProperties.solidFill=colr; b3.series.append(s)
b3.set_categories(Reference(cd,min_col=10,min_row=6,max_row=12)); b3.x_axis.scaling.orientation='maxMin'; b3.x_axis.delete=False; b3.y_axis.delete=False; b3.legend.position='b'
ws.add_chart(b3,'B40')
l4=LineChart(); l4.title='Selected commodity: risk score'; l4.height=7.5; l4.width=14.5; l4.legend=None
s=Series(Reference(cd,min_col=8,min_row=CH0,max_row=CH1),title='Risk score'); s.smooth=False; s.marker.symbol='none'; s.graphicalProperties.line.solidFill='C0392B'; s.graphicalProperties.line.width=22000; l4.series.append(s)
l4.set_categories(Reference(cd,min_col=5,min_row=CH0,max_row=CH1)); l4.x_axis.number_format='mmm yy'; l4.y_axis.scaling.min=0; l4.y_axis.scaling.max=100; l4.x_axis.delete=False; l4.y_axis.delete=False; l4.x_axis.tickLblSkip=3
ws.add_chart(l4,'H40')
# commentary
ws['B56']='Management commentary (auto-generated for the selected month)'; ws['B56'].font=F(size=12,bold=True,color=NAVY)
com=[f'="In "&$C$4&": "&COUNTIF({MV("M")},"Red")&" Red and "&COUNTIF({MV("M")},"Amber")&" Amber alerts among "&SUM({MV("P")})&" scored commodities. Highest risk: "&IFERROR(INDEX({MV("B")},MATCH(1,{MV("R")},0))&" (score "&TEXT(INDEX({MV("L")},MATCH(1,{MV("R")},0)),"0")&", "&INDEX({MV("N")},MATCH(1,{MV("R")},0))&")","n/a")&"."',
 f'="Largest monthly rise: "&IFERROR(INDEX({MV("B")},MATCH(1,{MV("T")},0))&" ("&TEXT(INDEX({MV("F")},MATCH(1,{MV("T")},0)),"+0.0%;-0.0%")&"); largest fall: "&INDEX({MV("B")},MATCH(1,{MV("U")},0))&" ("&TEXT(INDEX({MV("F")},MATCH(1,{MV("U")},0)),"+0.0%;-0.0%")&")","n/a")&"."',
 f'=COUNTIFS({MV("O")},"Statewide",{MV("P")},1)&" scored commodities show a statewide rise (breadth of "&TEXT({A(24)},"0%")&" or more of districts), which points to a supply or cost shock rather than a local issue."',
 f'="Data confidence: "&COUNTIF({MV("M")},"Low data")&" commodities are excluded this month because fewer than "&{A(19)}&" districts reported. Data runs to "&TEXT($M$4,"dd mmm yyyy")&"."']
for i,f_ in enumerate(com):
    r=57+i; ws.merge_cells(f'B{r}:N{r}'); ws[f'B{r}']=f_; ws[f'B{r}'].font=F(size=10); ws[f'B{r}'].alignment=Alignment(wrap_text=True,vertical='top'); ws.row_dimensions[r].height=30
ws['B62']='Analyst notes (static, as of data through 27 Feb 2026; edit freely)'; ws['B62'].font=F(size=12,bold=True,color=NAVY)
NOTES_ROW=63
# ---------------- notes computed from pandas replica ----------------
sc=score(m,sea).merge(di[['item_id','label']],on='item_id'); e=sc[sc.elig==1]
feb=e[e.month=='2026-02-01'].sort_values('risk',ascending=False); top=feb.iloc[0]
co=e[e.label.str.startswith('Coconut oil( Kera)')].set_index('month')
co_all=mm[mm.item_id==54].set_index('month').state_avg
peak_m=co_all.idxmax(); redm=[x.strftime('%b %Y') for x in co.index[co.cls=='Red']]
fm_=lambda v: f'{v:+.1%}'
tom=e[(e.label=='Tomato [Kg]')]
rc=e[e.cls=='Red'].groupby('label').size().sort_values(ascending=False)
rm=e.groupby('month').cls.apply(lambda s:int((s=='Red').sum()))
pk=[x.strftime('%b %Y') for x in rm.index[rm==rm.max()]]
nm_=lambda s:s.split(' [')[0]
notes_txt=[
 f"1) {nm_(top.label)} is the only Red alert in Feb 2026 (score {top.risk:.0f}): price {fm_(top.mom)} MoM and {fm_(top.yoy)} YoY, and {top.breadth:.0%} of districts are more than 10% above their own 12-month average, so the pattern is statewide rather than local.",
 f"2) Coconut oil (Kera) is the clearest structural story: state average rose from about Rs {co_all.iloc[0]:.0f}/L in Jan 2023 to a peak of Rs {co_all.max():.0f} in {peak_m.strftime('%b %Y')}; it was scored Red in {', '.join(redm)} and has eased since (Feb 2026: Rs {co_all.iloc[-1]:.0f}). Volatility stayed low because the rise was steady, which is why YoY and deviation are scored separately.",
 f"3) Most repeatedly flagged commodities since Jan 2024 (Red months): {nm_(rc.index[0])} {rc.iloc[0]}, {nm_(rc.index[1])} {rc.iloc[1]}, {nm_(rc.index[2])} {rc.iloc[2]}; tomato {int((tom.cls=='Red').sum())}. Tomato's July seasonal index of 171 rests on only 3 years and is largely driven by 2023.",
 f"4) Across Jan 2024 to Feb 2026 the number of Red commodities per month ranged from {int(rm.min())} to {int(rm.max())}, peaking in {' and '.join(pk)}; there were no Red alerts from Feb to May 2025.",
 "5) Limits: price-only data (no arrivals, stock or rainfall); 12 of 72 commodities are excluded in Feb 2026 for thin district coverage; supplied forecasts are not backtested."]
for i,t_ in enumerate(notes_txt):
    r=NOTES_ROW+i; ws.merge_cells(f'B{r}:N{r}'); ws[f'B{r}']=t_; ws[f'B{r}'].font=F(size=10,color='0000FF'); ws[f'B{r}'].fill=INP_FILL
    ws[f'B{r}'].alignment=Alignment(wrap_text=True,vertical='top'); ws.row_dimensions[r].height=44
open(BUILD/'notes.txt','w').write('\n'.join(notes_txt))
# ---------------- Data_Quality ----------------
ws=S['Data_Quality']; title(ws,'Data quality log & treatment','What was found in the source files and how this workbook handles it.')
for j,h in enumerate(['#','Issue','Evidence','Treatment in this workbook','Status'],1): ws.cell(4,j,h)
style_hdr(ws,4,1,5,NAVY,28)
dq=[('Item names embed units and have irregular spaces','Raw names such as "Rice(red)open market  Matta (Kg.)" (double spaces, unit suffixes)','Names and units cleaned in Dim_Item; display label = name [unit]; all joins use item_id','Fixed'),
('Two coconut items differ only by capitalisation/unit','item 20 "Coconut without Husk" (Kg, ~Rs 53) vs item 56 "Coconut without husk" (10 Nos, ~Rs 247)','Keyed on item_id; unit shown in label (Excel PivotTables/XLOOKUP are case-insensitive and would merge them)','Fixed'),
('Mixed units across items','Kg, Ltr, Dozen, 100gm, 10 Nos','Never average prices across items; use % changes and indexed comparisons only','By design'),
('Uneven district coverage by item','Some items reported by 1-3 districts (e.g. Mysore Vella rice: Wayanad only; KLF Nirmal coconut oil: Kollam 35 rows, Palakkad 399)','Confidence flag (High/Medium/Low) from districts reporting; Low items excluded from ranking, not scored zero','Handled'),
('Overall cell coverage about 80%','701,948 rows vs 14 districts x 72 items x 874 dates = 880,992 possible','Monthly aggregates need >=5 daily observations per district-month','Handled'),
('Source district_volatility.csv pools all items','Mean/std taken across items priced Rs 4 to Rs 570 in different units, so values (80-95%) reflect basket mix, not volatility','Not used; district view uses % premium vs state average per item','Replaced'),
('Source risk score mixed trend with volatility','Coconut oil (Kera) averaged Rs 161 in 2023 and Rs 375 in 2025; its high "volatility" was a level shift','New score separates volatility, deviation vs 12M average, YoY and momentum','Replaced'),
('Latest day has low coverage','27 Feb 2026: only 6 of 14 districts reported tomato (13-14 on normal days), so the day average (Rs 21.8) is not comparable','Monthly figures use district monthly means (>=5 obs), so one thin day has little effect; days with <10 districts are dropped from the Forecast actual series','Handled'),
('Feb 2026 has 21 reporting days','Feb 2025 had 22; data ends 27 Feb','Treated as a normal month; "Data through" date shown on Dashboard','Noted'),
('Seasonal index rests on 3 years','Tomato July index of 171 largely reflects the 2023 spike (Q3 2023 averaged Rs 73 vs Rs 46 and Rs 41 later)','Seasonal pressure carries only 10% weight and is labelled indicative','Noted'),
('Source grouping quirks','Onion small is grouped under Spices And Condiments, Onion big under Fruits And Vegetables, Carrot/Beetroot under Tubers','Source groups kept as supplied (group-level views follow them); remap in Dim_Item if needed','Noted'),
('Working-day reporting pattern','No Sunday records; Saturdays appear on 119 of about 164 Saturdays; 69 Monday-Friday dates are absent (874 reporting dates in 1,152 calendar days)','Absent dates are not treated as missing data; coverage is measured against reporting dates, and monthly metrics need >=5 daily observations per district-month','Noted'),
('Prices often unchanged day to day','88.9% of daily prices equal the previous record for the same district and commodity; no single date has more than 94.5% unchanged, so no whole-day copies. The source dashboard is reported to show the last available day when data are missing, so some unchanged values may be carried forward','Cannot separate stale from genuinely unchanged prices; monthly means dampen but do not remove the effect; treat very low volatility with caution','Limitation'),
('Single-day jumps','224 daily changes above 50% (6 above 100%), mostly vegetables','Left in the data (plausible for perishables); monthly means damp their effect','Noted'),
('Forecast files cover 3 items only; method undocumented','Tomato, Ladies Finger, Coconut oil (Kera); 90 days from 28 Feb 2026; Tomato forecast starts well above recent actuals','Shown as scenarios with sanity checks; backtest recommended before use','Open'),
('No supply-side data','Dataset has prices only','"Supply stress" inferred from district dispersion, breadth of rise and seasonality; add arrivals/stock/rainfall as next step','Limitation')]
for i,row in enumerate(dq):
    r=5+i; ws.cell(r,1,i+1)
    for j,v in enumerate(row,2): ws.cell(r,j,v)
    for c in range(1,6): ws.cell(r,c).font=F(size=9); ws.cell(r,c).alignment=Alignment(wrap_text=True,vertical='top'); ws.cell(r,c).border=box
r0=5+len(dq)+2; ws.cell(r0,1,'Source file quality report (data_quality_report.csv)').font=F(bold=True,color=NAVY,size=11)
dqr=pd.read_csv(U+'data_quality_report.csv')
for j,h in enumerate(dqr.columns,1): ws.cell(r0+1,j,h)
style_hdr(ws,r0+1,1,len(dqr.columns),TEAL,24)
for i,row in dqr.iterrows():
    for j,v in enumerate(row,1): ws.cell(r0+2+i,j,v if not isinstance(v,(np.integer,)) else int(v)).font=F(size=9)
setw(ws,{'A':14,'B':44,'C':60,'D':64,'E':12,'F':12,'G':10,'H':14,'I':16})
# ---------------- Model_Guide ----------------
ws=S['Model_Guide']; title(ws,'Excel Data Model & DAX guide (to rebuild the 700K-row model in Excel)','This workbook holds monthly aggregates so it stays fast. The full daily table (701,948 rows) belongs in the Power Pivot Data Model, loaded with Power Query.')
guide=['LOAD (Data > Get Data > From Text/CSV, then Load To... Data Model only):',
'  fact_daily_prices_clean.csv, dim_item.csv, dim_district.csv, dim_date.csv  (use item_id, district_id, date_id as keys)',
'RELATIONSHIPS: fact[item_id]->dim_item[item_id]; fact[district_id]->dim_district[district_id]; fact[date_id]->dim_date[date_id] (many-to-one, single direction).',
'POWER QUERY CLEANING: Trim and collapse spaces in item names; split unit from name; clean group "Oil And Oil  Seeds"; set price to decimal; keep source_file for lineage.',
'DAX MEASURES:',
'  Avg Price = AVERAGE(fact_daily_prices_clean[price])',
'  Avg Price LM = CALCULATE([Avg Price], DATEADD(dim_date[full_date], -1, MONTH))',
'  MoM % = DIVIDE([Avg Price] - [Avg Price LM], [Avg Price LM])',
'  Avg Price LY = CALCULATE([Avg Price], SAMEPERIODLASTYEAR(dim_date[full_date]))',
'  YoY % = DIVIDE([Avg Price] - [Avg Price LY], [Avg Price LY])',
'  12M Avg (prior) = CALCULATE([Avg Price], DATESINPERIOD(dim_date[full_date], EOMONTH(MAX(dim_date[full_date]), -1), -12, MONTH))',
'  Vs 12M Avg % = DIVIDE([Avg Price] - [12M Avg (prior)], [12M Avg (prior)])',
'  Districts Reporting = DISTINCTCOUNT(fact_daily_prices_clean[district_id])',
'NOTE: this sheet\'s state average is the mean of district monthly means (equal district weight); a plain AVERAGE over daily rows weights districts by number of observations. Differences are small (median 0.02%) but document which one you use.',
'SLICERS: add PivotTables on the Data Model and insert Slicers/Timelines for Group, District and Month (openpyxl cannot create slicers; this workbook uses drop-downs on the Dashboard instead).']
for i,t in enumerate(guide): ws.cell(4+i,1,t).font=F(size=10,bold=t.endswith(':'))
ws.column_dimensions['A'].width=160
# ---------------- README ----------------
ws=S['README']; title(ws,'Kerala Essential Commodities: Price & Supply-Stress Intelligence (Excel MIS project)')
rd=[('PURPOSE',''),
('Business question','Which essential commodities and which districts face the highest risk of price spikes or supply stress next month, and what should be done?'),
('Audience','Civil supplies / procurement / price-monitoring officers and MIS reviewers who need a monthly exception report.'),
('HOW TO USE',''),
('1','Go to Dashboard. Pick a month (cell C4) and a commodity for the trend charts (cell G4).'),
('2','Read the KPI cards and the Top 10 alerts; open Watchlist for the full exception report with suggested actions.'),
('3','Use Group_Heatmap for 12-month trends by group and District_View for district price premiums.'),
('4','Change weights, caps and thresholds on Assumptions (blue cells); everything recalculates.'),
('SHEET MAP',''),
('Dashboard / Watchlist / Group_Heatmap / District_View / Forecast','Reporting sheets (red tabs).'),
('Assumptions','Scoring weights, caps, thresholds (yellow tab).'),
('Month_View / Chart_Data','Helper sheets driven by the selected month (grey tabs).'),
('Data_Calc','Commodity x month table (2,736 rows): source aggregates (blue headers) + live formulas for MoM, YoY, 12M average, volatility, component scores, risk score, class (teal headers).'),
('Data_District','District x commodity x month prices (31K rows) for the district premium view.'),
('Dim_Item / Seasonal / Months / Lists','Reference tables.'),
('Data_Quality / Model_Guide','Issues found and how they were handled; steps to rebuild the full Data Model and DAX measures.'),
('METHOD',''),
('Risk score','Weighted average (0-100) of seven component scores: momentum, volatility, deviation vs prior-12M average, YoY change, district dispersion, breadth of rise, seasonal pressure. Each component = MIN(1, value/cap) x 100; rises only (upside pressure on consumers). Class: Red >= 65, Amber >= 40, else Green (adjustable).'),
('Risk type','Sustained surge (YoY >= 40% and above 12M average by >= 10%), Short-term spike (MoM >= 20%), Volatile (12M volatility >= 12%), else Stable.'),
('Spread signal','Statewide / Regional / Isolated, from the share of districts more than 10% above their own prior-12M average.'),
('Confidence','High (>=10 districts reporting), Medium (>=5), Low (<5; excluded from ranking).'),
('SOURCES & ASSUMPTIONS',''),
('Price data','Daily retail prices of essential commodities from the Department of Economics and Statistics, Government of Kerala (ecostat.kerala.gov.in: Essential Commodity Price Dataset 67 and the State Dashboard on Prices of Essential Commodities). Collected at the 14 district headquarters on working days. Yearly source files 2023-2026 were cleaned into fact_daily_prices_clean.csv (3 Jan 2023 to 27 Feb 2026). Independent analysis: not an official DES statistic and not endorsed by DES.'),
('Aggregation','Monthly state average = equal-weight mean of district monthly means; a district-month needs >=5 daily observations. Aggregates were prepared in Python (pandas) from the cleaned fact table; this is the only non-formula input to Data_Calc (blue headers).'),
('Forecasts','Supplied with the dataset for 3 commodities; method undocumented; not backtested. Indicative scenarios only.'),
('LIMITATIONS','No arrivals, stock, rainfall or import-dependency data: this is a price-risk early-warning tool with supply-stress proxies, not a shortage forecast. Weights/caps are analyst judgement calibrated on 2024-2026 data. Seasonal index uses only 3 years. See Data_Quality for the full log.'),
('NEXT STEPS','Backtest forecasts on a hold-out period; add rainfall and market arrivals; add district-level risk scores; load the full model into Power Pivot using Model_Guide.')]
r=3
for a,b in rd:
    if b=='' : 
        ws.cell(r,1,a).font=F(bold=True,color='FFFFFF'); ws.cell(r,1).fill=fill(NAVY); ws.cell(r,2).fill=fill(NAVY)
    else:
        ws.cell(r,1,a).font=F(bold=True,size=9); ws.cell(r,2,b).font=F(size=10)
        ws.cell(r,1).alignment=Alignment(wrap_text=True,vertical='top'); ws.cell(r,2).alignment=Alignment(wrap_text=True,vertical='top')
    r+=1
setw(ws,{'A':44,'B':120})
# workbook-level
for w_ in wb.worksheets:
    if w_.title not in ('Dashboard',): w_.sheet_view.showGridLines=False if w_.title in ('README','Assumptions','Watchlist','Group_Heatmap','District_View','Forecast') else True
wb.active=1
import os
OUT=os.environ.get('MIS_OUT',str(BUILD/'Kerala_Commodity_Price_Risk_MIS_rebuilt.xlsx'))  # never overwrites the committed workbook by default
from openpyxl.workbook.properties import CalcProperties
wb.calculation=CalcProperties(fullCalcOnLoad=True)
wb.save(OUT); print('saved',OUT)
