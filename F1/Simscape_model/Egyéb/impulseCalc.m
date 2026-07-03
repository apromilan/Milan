tRange=[4,5];
indexes=find(out.tout>=tRange(1)&out.tout<=tRange(2));
t=out.tout(indexes)-out.tout(indexes(1));
y=out.simout.Data(indexes,2); %Front pushrod

info.SettlingTime=stepinfo(y,t).SettlingTime;
info.SettlingMin=stepinfo(y,t).SettlingMin;
info.SettlingMax=stepinfo(y,t).SettlingMax;
info.Peak=stepinfo(y,t).Peak;
info.PeakTime=stepinfo(y,t).PeakTime;
info