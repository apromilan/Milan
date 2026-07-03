load 00_merged.mat

plot(heaveData_merged(:,1),heaveData_merged(:,3), '.', "MarkerSize",10);
grid;
xlabel("Excitation frequency [Hz]");
ylabel("Droplink force amplitude [N]");