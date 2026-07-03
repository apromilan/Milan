function amplitudes = AmpCalc(simOut,delay)
%AMPCALC Amplitude calculation for simOut data.
%   simOut - simulation output
%   delay  - time reserved for the decay of transients

amplitudes=zeros(1,length(simOut.simout.Data(1,:)));
StartIndex=find(simOut.tout>=delay);
StartIndex=StartIndex(1);
for j =1:length(amplitudes)
   amplitudes(j)=peak2peak(simOut.simout.Data(StartIndex:end,j))/2; 
end
end

