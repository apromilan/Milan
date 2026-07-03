%Eigenfrequency calculator script for FRED-002 Lola.
%BME FRT 2022, Bajuszcrew ©
%Péter Pácsonyi
clear;
%Halfvehicle model
m_f=27.25;  %[kg]
m_r=27.24;  %[kg]
m_s=198.86; %[kg]
Theta_s=62.71; %[kgm^2]
motionRatio_front=1.112;
motionRatio_rear=1.053;
c_f=0.88021*1000/(motionRatio_front^2)*2;
c_r=0.88021*1000/(motionRatio_rear^2)*2;
k_f=150*175.127/(motionRatio_front^2)*2;
k_r=150*175.127/(motionRatio_rear^2)*2;
k_t=300*1000*2;
g=9.81;
wheelbase=1.54;
weight_dist_front=0.4757;
l_f=(1-weight_dist_front)*wheelbase;
l_r=(weight_dist_front)*wheelbase;

%syms m_f m_r m_s Theta_s c_f c_r k_f k_r k_t g l_f l_r

syms z_f z_r z_s phi dz_f dz_r dz_s dphi

q=[z_f;z_r;z_s;phi];
dq=[dz_f;dz_r;dz_s;dphi];

T=0.5*m_f*(dz_f)^2+0.5*m_r*(dz_r)^2+0.5*m_s*(dz_s)^2+0.5*Theta_s*dphi^2;
U=m_f*g*z_f+m_r*g*z_r+m_s*g*z_s+0.5*k_f*(z_f+l_f*sin(phi)-z_s)^2+0.5*k_r*(z_r-l_r*sin(phi)-z_s)^2+0.5*k_t*z_f^2+0.5*k_t*z_r^2;
D=0.5*c_f*(dz_f+l_f*dphi*cos(phi)-dz_s)^2+0.5*c_r*(dz_r-l_r*dphi*cos(phi)-dz_s)^2;

M=double(subs(LagrangeDiff(T,dq),q,zeros(length(q),1)));
C=double(subs(LagrangeDiff(D,dq),q,zeros(length(q),1)));
K=double(subs(LagrangeDiff(U,q),q,zeros(length(q),1)));

% M=subs(LagrangeDiff(T,dq),q,zeros(length(q),1))
% C=subs(LagrangeDiff(D,dq),q,zeros(length(q),1))
% K=subs(LagrangeDiff(U,q),q,zeros(length(q),1))

H=[zeros(length(q)),eye(length(q));-inv(M)*K,-inv(M)*C];

[modes,eigangfreqsM]=eig(H);
eigangfreqs=zeros(length(q),1);
eigfreqs=zeros(length(q),1);
zetas=zeros(length(q),1);
for j=1:length(q)
    eigangfreqs(j)=imag(eigangfreqsM(j*2-1,j*2-1));
    eigfreqs(j)=imag(eigangfreqsM(j*2-1,j*2-1))/(2*pi);
    zetas0(j)=-real(eigangfreqsM(j*2-1,j*2-1))/abs(eigangfreqsM(j*2-1,j*2-1));
    A0(:,j)=modes(1:4,j*2-1);
end
[omega_d,ind]=sort(eigangfreqs);
f_d=sort(eigfreqs);
zetas=zetas0(ind);
A=abs(A0(:,ind));

for j=1:length(q)
   disp(['omega_d',num2str(j),' = ',num2str(omega_d(j)),' [rad/s]']);
   disp(['f_d',num2str(j),' = ',num2str(f_d(j)),' [Hz]']);
   disp(['zeta',num2str(j),' = ',num2str(zetas(j)),' [-]']);
   disp(['A_',num2str(j),' =']);
   disp(A(:,j))
end

function M=LagrangeDiff(fun,q)
for j=1:length(q)
   for k=1:length(q)
       M(j,k)=diff(fun,q(j),q(k));
   end
end
end

