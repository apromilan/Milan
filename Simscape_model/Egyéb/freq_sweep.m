run("Point_setup.m");
%freqs=linspace(0.1,25,50);
freqs=[4.2:0.1:6.5,22:0.1:25];
gains=[1,1,1,1];
delay=2;
for j=3:3
    switch j
        case 1
            gains=[1,1,1,1];
            heaveData=zeros(length(freqs),15);
        case 2
            gains=[1,-1,1,-1];
            rollData=zeros(length(freqs),15);
        case 3
            gains=[1,1,-1,-1];
            pitchData=zeros(length(freqs),15);
    end
            
    
    for k =1:length(freqs)
        freq=freqs(k);
        simOut=sim("MASTER.slx",max(3,2+1/freq));
        switch j
          case 1
                heaveData(k,:)=[freq,AmpCalc(simOut,delay)];
          case 2
              rollData(k,:)=[freq,AmpCalc(simOut,delay)];
          case 3
              pitchData(k,:)=[freq,AmpCalc(simOut,delay)];
        end
    end
    
    switch j
        case 1
            save 01_heave_dense.mat heaveData;
            disp("Heave done");
        case 2
            save 02_roll_dense.mat rollData;
            disp("Roll done");
        case 3
            save 03_pitch_dense.mat pitchData;
            disp("Pitch done");
    end
end


