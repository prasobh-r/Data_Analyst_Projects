"""Risk-score logic (pandas replica used to verify the Excel formulas).

Weights, caps and thresholds mirror the Assumptions sheet of the workbook."""
import pandas as pd, numpy as np
W=dict(mom=.20,vol=.15,dev=.20,yoy=.15,disp=.10,brd=.10,sea=.10)
CAP=dict(mom=.15,vol=.15,dev=.30,yoy=.60,disp=.25,brd=.50,sea=25)
TH=dict(red=65,amber=40,hi=10,med=5,surge=.40,surgedev=.10,spike=.20,volatile=.12,state=.50,region=.20)
def score(m,sea,W=W,CAP=CAP,TH=TH):
    m=m.sort_values(['item_id','month']).reset_index(drop=True).copy()
    m['idx']=m.groupby('item_id').cumcount()+1
    g=m.groupby('item_id')
    m['mom']=m.state_avg/g.state_avg.shift(1)-1
    m['avg12']=g.state_avg.transform(lambda x:x.shift(1).rolling(12,min_periods=8).mean())
    m['dev']=m.state_avg/m.avg12-1
    m['vol']=g.mom.transform(lambda x:x.rolling(12,min_periods=8).std())
    m['yoy']=m.state_avg/g.state_avg.shift(12)-1
    m['mon']=m.month.dt.month
    m=m.merge(sea[['item_id','month','seasonal_index']].rename(columns={'month':'mon'}),on=['item_id','mon'],how='left')
    m['conf']=np.where(m.n_districts.isna(),'No data',np.where(m.n_districts>=TH['hi'],'High',np.where(m.n_districts>=TH['med'],'Medium','Low')))
    m['elig']=((m.idx>=13)&m.state_avg.notna()&m.mom.notna()&m.dev.notna()&m.vol.notna()&m.conf.isin(['High','Medium'])).astype(int)
    cl=lambda x:np.minimum(1,np.maximum(0,x))
    m['s_mom']=cl(m.mom/CAP['mom'])*100
    m['s_vol']=cl(m.vol/CAP['vol'])*100
    m['s_dev']=cl(m.dev/CAP['dev'])*100
    m['s_yoy']=cl(m.yoy.fillna(0)/CAP['yoy'])*100
    m['s_disp']=cl(m.disp_cv.fillna(0)/CAP['disp'])*100
    m['s_brd']=cl(m.breadth.fillna(0)/CAP['brd'])*100
    m['s_sea']=cl((m.seasonal_index.fillna(100)-100)/CAP['sea'])*100
    m['risk']=(W['mom']*m.s_mom+W['vol']*m.s_vol+W['dev']*m.s_dev+W['yoy']*m.s_yoy+W['disp']*m.s_disp+W['brd']*m.s_brd+W['sea']*m.s_sea)/sum(W.values())
    m.loc[m.elig==0,'risk']=np.nan
    m['cls']=np.where(m.elig==1,np.where(m.risk>=TH['red'],'Red',np.where(m.risk>=TH['amber'],'Amber','Green')),'')
    m['type']=np.where(m.elig==1,np.where((m.yoy>=TH['surge'])&(m.dev>=TH['surgedev']),'Sustained surge',np.where(m.mom>=TH['spike'],'Short-term spike',np.where(m.vol>=TH['volatile'],'Volatile','Stable'))),'')
    m['signal']=np.where(m.elig==1,np.where(m.breadth>=TH['state'],'Statewide',np.where(m.breadth>=TH['region'],'Regional','Isolated/none')),'')
    return m
