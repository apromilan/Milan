tRange=[0,3];
indexes=find(out.tout>=tRange(1)&out.tout<=tRange(2));
t=out.tout(indexes)-out.tout(indexes(1));
y1=out.simout.Data(indexes,3); %Front pushrod

y2=out.simout.Data(indexes,4);
plot(t,y1,'LineWidth',2);
grid
xlabel('t [s]')
ylabel('Rod force [N]')


hold on
plot(t,y2,'LineWidth',2);
legend('UCA front','UCA rear')