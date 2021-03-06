%% A 4th version of VFI for Mendoza and Yue.

clear all; 
alpha_m=.43; % share of intermediate goods in gross output
gamma=.7; % labor income share in value added and in intermediate goods production
alpha_L=(1-alpha_m)*gamma;
alpha_k=1-alpha_m-alpha_L;
sigma=2; % coef. of relative risk aversion
Rstar=1.01; % risk-free interest rate
omega=1.455; % curvature of labor supply, 1/(omega-1)=Frisch wage elasticity
phi=.083; % reentry probability
lambda=.62; % armington weight of domestic inputs
mu=.65; % armington curvature parameter
nu=.59; % Dixit-Stiglitz curvature parameter
A=.31; % intermediate goods TFP coefficient
beta=.88; % subjective discount factor
theta=.7; % upper bound of imported inputs with working capital
xi=0;%-.67; % TFP semi-elasticity of exogenous capital flows
rho_z=.95; sigma_z=0.017; % sigma_z = 0.017
mu_z=0;%-sigma_z^2/(1-rho_z^2)/2; 

numz = 25; % (25) number of TFP realizations for Tauchen's method of TFP discretization
numb = 11; % number of bonds in bond space. Not given by MY, so I set to 11, so the 6th one is 0.
cover = 3; % coverage parameter for Tauchen. This value MY don't tell, so I set to default value of 3
lbb = -10; % lower bound for bond space
ubb = 10; % uppe bound for bond space

[Z,P,~] = tauchen_MY(cover,sigma_z, rho_z, mu_z, numz, lbb, ubb, numb); 
e=exp(Z'); % shock process
[~,ei]=sort(e); % ei becomes the index of e (~ is being ignored by def.)
E = size(e,2); % =numz 
%% Factor market equilibrium
% Simplify 8-dimensional eq system to a 3-dimensional one in Lf, Lm and ms
fun=@(L,ps,ej) [alpha_m*ej*(lambda*(A*L(2)^gamma)^mu + (1-lambda)*L(3)^mu)^((alpha_m-mu)/mu)*L(1)^alpha_L*(1-lambda)*L(3)^(mu-1) - ps
    alpha_m*ej*(lambda*(A*L(2)^gamma)^mu + (1-lambda)*L(3)^mu)^((alpha_m-mu)/mu)*L(1)^alpha_L * lambda*(A*L(2)^gamma)^(mu-1) - (L(1)+L(2))^(omega-1)/(gamma*A*L(2)^(gamma-1))
    alpha_L*ej*(lambda*(A*L(2)^gamma)^mu + (1-lambda)*L(3)^mu)^(alpha_m/mu)*L(1)^(alpha_L -1) - (L(1)+L(2))^(omega-1)];
ps=(theta*[Rstar^(nu/(nu-1));0]+1-theta).^(1-1/nu);
L=nan(2,E,3); % regime(g|b) x shock(e) x sector(f|m) and ms
o=optimset('Display','off');
for i=1:2
    for j=1:E
        L(i,j,:)=fsolve(@(L) fun(L,ps(i),e(j)),[.07 .05 .005],o);
    end
end
Lf=L(:,:,1); Lm=L(:,:,2); ms=L(:,:,3);
L= Lf + Lm;
w=L.^(omega-1);
y=w.*Lf/alpha_L; % final production
md=A*Lm.^gamma;
pm=w.*Lm./md/gamma;
M=(lambda*md.^mu+(1-lambda)*ms.^mu).^(1/mu);
gdp=y-bsxfun(@times,ps,ms); %applies the element-by-element binary operation specified by the function handle 

E0 = round(E/2); % look at the effect in the middle of shock space
disp('Effects of default on factor allocations in percent:')
fprintf('M\t%.2f\n',(M(2,E0)/M(1,E0)-1)*100)
fprintf('m*\t%.2f\n',(ms(2,E0)/ms(1,E0)-1)*100)
fprintf('md\t%.2f\n',(md(2,E0)/md(1,E0)-1)*100)
fprintf('L\t%.2f\n',(L(2,E0)/L(1,E0)-1)*100)
fprintf('Lf\t%.2f\n',(Lf(2,E0)/Lf(1,E0)-1)*100)
fprintf('Lm\t%.2f\n',(Lm(2,E0)/Lm(1,E0)-1)*100)

%% The planner's problem as VFI
B=100; % 501
bmax=.05; b=linspace(0,bmax,B)'; % discretize bond space
bP=bsxfun(@times,beta,P); % Markov probability adjusted discount factor
iP=eye(E)-(1-phi)*bP; % Markov probability and readmission prob adjusted discount factor
rep = repmat(b',B*E,1); % create B*E rows of b'
bp=reshape(rep,B,E*B); % create a B x EB matrix of bond values (tomorrow's bonds)
cL=gdp-L.^omega/omega-bsxfun(@times,xi*log(e),gdp); % "consumption" (2xE, good or bad x shock space)
% (cL is a composite of cons and labor, i.e. it's the input to the utility function)
ub=cL(2,:).^(1-sigma)/(1-sigma); % bad utility (1xE)
ub=ub/iP; % discount it
bPi=bP/iP; % overall discount factor of bad scenario
if exist('init_guess','file'), load(f,'D','v'), else D=true(B,E); v=zeros(B,E); end 
% load in previous value, else set initial guess to zero for value, ones for decision
dD=1; dv=1; % initialize errors
dvmin=1e-5; % initialize
tic
while dD>0||dv>0
    q=(1-D*P)/Rstar; % set bond price (BxE)
    q(q<0)=0; % make sure it's nonnegative
    D_old=D; dv=1;
    % define utility of good case as good cons + bond*price - b_p [B x EB]
    ug=repmat(bsxfun(@plus,cL(1,:),bsxfun(@times,q,b)),1,B)-bp; % deleted a *g from a here
    ug(ug<0)=0; ug=ug.^(1-sigma)/(1-sigma);
    while dv>dvmin % as long as value has not converged...
        vb=ub+phi*v(1,:)*bPi; % set bad value (1xE)
        vg=reshape(max(ug+repmat(v*bP,1,B)),E,B)'; % good value is the max for different b_p choices [BxE]
        D=bsxfun(@gt,vb,vg); % default = 1 if vb > vg
        [~,i]=find(D); % find where default occurs (D !=0)
        vg(D)=vb(i); % when you default, replace vg with vb
        dv=max(max(abs(vg./v-1))); % evaluate the error
        v=vg; % update value
    end
    dD=sum(D(:)~=D_old(:)); % error = sum the number of times D unequal to D_old
    fprintf('dD=%g\n',dD)
    if dD==0; dvmin=0; end % if D has converged, set dvmin = 0 to end the big while loop 
end,toc

[~,ap]=max(ug+repmat(v*bP,1,B)); % get the debt position of max values (i.e. index of debt stance where value is maximized)
ap=reshape(ap,E,B)'; ap(D)=0; % set debt position to 0 for default, leave it at whatever other value it was for no default.
save('init_guess','D','v') % save updated v as initial guess
ad=reshape(b(sum(~D))+b(2)/2,1,E); % the realized debt choices w/o default
%le=reshape(log(e),Z,G);
le=log(e);
figure(1), plot(ad,le,'r','linewidth',2)
title('Default set'),xlabel('Debt'),ylabel('log TFP')

figure(2),hold on,plot(b,q(:,[E0]),'Color','b','linewidth',2), title('Bond price at median TFP'),xlabel('Debt')
% takes 3 min
figure(3), mesh(Z, b, q), title('Bond price as function of debt and productivity'),xlabel('Debt'), ylabel('log TFP')

%% Simulation to get Table III and Fig. VI or V.
T = 500; % total number of periods (given by Mendoza and Yue)
TT = 400; % truncated number of periods (T- burn-in) (given by Mendoza and Yue)
ns = 2000; % number of simulations, each at TT periods (given by Mendoza and Yue)
S = zeros(T,8); % variables matrix (time periods x 8 variables)
H = zeros(T,3); % history matrix (time periods x [default or no], debt level, tfp draw)

sim_means = zeros(ns,8);
sim_vars  = zeros(ns,8); 
sim_corrs = zeros(ns,7);

for n=1:ns % for each simulation MAKE THE SIMULATION WORK
    Dh = zeros(T,1); % initialized default history
    Dt_old = 0; % initialize yesterday's decision as no default
    % Draw TFP, draw reentry and initialize bond position:
%     tfp_index = randi(size(Z,1),T,1); % e(tfp_index) is the tfp draw
    s=rand(T,1); % random draws for TFP innovations which will be chosen based on Markov probabilities
    F=cumsum(P);
    re=rand(T,1)<phi; % reentry draws: random draws =1 with probability phi
    % I select the initial debt position randomly
    bond_index = randi(size(b,1)); % b(bond_index) is the initial bond position
    tfp_index = randi(size(e,1)); % e(tfp_index) is the initial bond position
    i = bond_index; % rename for simplicity
    j = tfp_index; % rename for simplicity so that e(j) is the initial tfp draw
    for t = 1:T % for each time period
        debt_stance=ap(i,j); % the current default decision as summarized by debt stance (if zero, then default, else it gives position of debt in debt matrix)
        % check default in current state
        if debt_stance == 0 || Dt_old == 1 %default, then set all variables to their default values
            R=nan;
            GDP=gdp(2,j); 
            TB=xi*log(e(j))*GDP;
            MS=ms(2,j);
            IM=M(2,j);
            L_=L(2,j);
            Dt_old = 1; %update default stance
            debt_stance = 1; % set this to 1 in order to be a nonzero index
            i = find(~b); %update debt index to be such that debts are zero
            reentry = re(t); %pick whether country can reenter asset markets next period
            if reentry == 1; Dt_old = 0; end % even if default today, if the country reenters tomorrow I set old state to ok
        else
            R=1/q(i,j)^4-Rstar^4; % sovereign bond spread (annual)
            GDP=gdp(1,j); % real GDP
            TB=b(i)-b(i)*q(i,j)+xi*log(e(j))*GDP; % trade balance
            MS=ms(1,j); % imported intermediate inputs
            IM=M(1,j); % total intermediate goods
            L_=L(1,j); % labor
            Dt_old = 0; %update default stance
        end
        CONS=GDP-TB; % consumption
        S(t,:)=[GDP CONS R TB/GDP L_ IM MS b(i)/GDP]; % "state" variables
        Dh(t) = debt_stance; % update default history
        H(t,:)=[Dh(t) i j]; % history variables
        i = debt_stance; % update location
        j=find(s(t)<F(:,j),1); % update TFP draw using Markov chain
        
    end
    S(:,[1 2 4 6 7])=log(S(:,[1 2 4 6 7])); % take logs for most variables
    S(:,[1 2 4 6 7])=detrend(S(:,[1 2 4 6 7])); % detrend those same variables
    sim_means(ns,:)=nanmean(S(T-TT+1:T,:)); % for simulation means, take the nanmean starting from after the burn-in
    sim_vars(ns,:)=nanvar(S(T-TT+1:T,:)); % same for variance
    % Below: calculate correlation between variables (except last one)
    corr_coeffs=nancov(S(T-TT+1:T,1:6))./sqrt(sim_vars(ns,1:6)'*sim_vars(ns,1:6)); % correlation coefficients
    sim_corrs(ns,:)=[corr_coeffs(1,3:6) corr_coeffs(3,4:6)]; % gather the correlations we need for Table III
    % Below: get correlations with default history
    corr_coeffs2=corrcoef([S(T-TT+1:T,1) Dh(T-TT+1:T)]);
    auto_corrs=corrcoef(S(T-TT+1:T-1,1),S(T-TT+2:T,1));
    STAT(ns,:)=[corr_coeffs2(2) mean(Dh(H(:,2)>1)) auto_corrs(2)];
end
% Reproduce averages in Table III:
S=mean(sim_means); 
Sv=sqrt(mean(sim_vars)); % get standard deviation
fprintf('Average debt/GDP ratio %.2f%%\n',S(8)*100) %
fprintf('Average bond spreads %.2f%%\n',S(3)*100) %
fprintf('Std. dev. of bond spreads %.2f%%\n',Sv(3)*100) %
fprintf('Consumption std.dev./GDP std.dev. %.2f\n',Sv(2)/Sv(1))%
fprintf('Correlations with GDP\n')
fprintf('   bond spreads %.2f\n',sim_corrs(1))%
fprintf('   trade balance %.2f\n',sim_corrs(2))%
fprintf('   labor %.2f\n',sim_corrs(3))%
fprintf('   intermediate goods %.2f\n',sim_corrs(4)) %
fprintf('Correlations with bond spreads\n') 
fprintf('   trade balance %.2f\n',sim_corrs(5)) %
fprintf('   labor %.2f\n',sim_corrs(6)) %
fprintf('   intermediate goods %.2f\n',sim_corrs(7)) %
return
fprintf('Historical default-output co-movements\n')
fprintf('   correlation between default and GDP %.2f\n',STAT(1)) %
fprintf('   fraction of defaults with GDP below trend %.2f%%\n',mean(Sd(dtmax+1,1,:)<0)*100) %
fprintf('   fraction of defaults with large recessions %.2f%%\n',mean(Sd(dtmax+1,1,:)<-2*Sv(1))*100) %
