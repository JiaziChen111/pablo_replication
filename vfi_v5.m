%% A 5th version of VFI for Mendoza and Yue.
% all unchanged; here only cleaning up and renaming.

clear all; 
alpha_m=.43; % share of intermediate goods in gross output
gam=.7; % labor income share in value added and in intermediate goods production
alpha_L=(1-alpha_m)*gam;
alpha_k=1-alpha_m-alpha_L;
sigm=2; % coef. of relative risk aversion
r=1.01; % risk-free interest rate
omega=1.455; % curvature of labor supply, 1/(omega-1)=Frisch wage elasticity
phi=.083; % reentry probability
lam=.62; % armington weight of domestic inputs
mu=.65; % armington curvature parameter
nu=.59; % Dixit-Stiglitz curvature parameter
A=.31; % intermediate goods TFP coefficient
bet=.88; % subjective discount factor
thet=.7; % upper bound of imported inputs with working capital
xi=0;%-.67; % TFP semi-elasticity of exogenous capital flows
rho_z=.95; sigma_z=0.017; % sigma_z = 0.017
mu_z=0;%-sigma_z^2/(1-rho_z^2)/2; 

numz = 25; % (25) number of TFP realizations for Tauchen's method of TFP discretization
numb = 100; % number of bonds in bond space. Not given by MY, so I set to 11, so the 6th one is 0.
cover = 3; % coverage parameter for Tauchen. This value MY don't tell, so I set to default value of 3
lbb = 0; % lower bound for bond space
ubb = .05; % uppe bound for bond space

[Z,P,b] = tauchen_MY(cover,sigma_z, rho_z, mu_z, numz, lbb, ubb, numb); 
e=exp(Z'); % shock process
E = size(e,2); % =numz (rename for simplicity)
B = numb; % rename for simplicity
%% Factor market equilibrium
% Simplify 8-dimensional eq system to a 3-dimensional one in Lf, Lm and ms
fun=@(L,ps,ej) [alpha_m*ej*(lam*(A*L(2)^gam)^mu + (1-lam)*L(3)^mu)^((alpha_m-mu)/mu)*L(1)^alpha_L*(1-lam)*L(3)^(mu-1) - ps
    alpha_m*ej*(lam*(A*L(2)^gam)^mu + (1-lam)*L(3)^mu)^((alpha_m-mu)/mu)*L(1)^alpha_L * lam*(A*L(2)^gam)^(mu-1) - (L(1)+L(2))^(omega-1)/(gam*A*L(2)^(gam-1))
    alpha_L*ej*(lam*(A*L(2)^gam)^mu + (1-lam)*L(3)^mu)^(alpha_m/mu)*L(1)^(alpha_L -1) - (L(1)+L(2))^(omega-1)];
ps=(thet*[r^(nu/(nu-1));0]+1-thet).^(1-1/nu);
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
md=A*Lm.^gam;
pm=w.*Lm./md/gam;
M=(lam*md.^mu+(1-lam)*ms.^mu).^(1/mu);
gdp=y-bsxfun(@times,ps,ms); 

%% The planner's problem as VFI
betP=bsxfun(@times,bet,P); % Markov probability adjusted discount factor
phiBetP=eye(E)-(1-phi)*betP; % Markov probability and readmission prob adjusted discount factor
rep = repmat(b',B*E,1); % create B*E rows of b'
bp=reshape(rep,B,E*B); % create a B x EB matrix of bond values (tomorrow's bonds)
cL=gdp-L.^omega/omega-bsxfun(@times,xi*log(e),gdp); % "consumption" (2xE, good or bad x shock space)
% (cL is a composite of cons and labor, i.e. it's the input to the utility function)
u_bad=cL(2,:).^(1-sigm)/(1-sigm); % bad utility (1xE)
u_bad=u_bad/phiBetP; % discount it
odf=betP/phiBetP; % overall discount factor of bad scenario
if exist('init_guess','file'), load(f,'D','v'), else D=true(B,E); v=zeros(B,E); end 
% load in previous value, else set initial guess to zero for value, ones for decision
errD=1; errV=1; % initialize errors
dvmin=1e-5; % initialize
tic
while errD>0||errV>0
    q=(1-D*P)/r; % set bond price (BxE)
    q(q<0)=0; % make sure it's nonnegative
    D_old=D; errV=1;
    % define utility of good case as good cons + bond*price - b_p [B x EB]
    u_good=repmat(bsxfun(@plus,cL(1,:),bsxfun(@times,q,b)),1,B)-bp; % deleted a *g from a here
    u_good(u_good<0)=0; u_good=u_good.^(1-sigm)/(1-sigm);
    while errV>dvmin % as long as value has not converged...
        v_bad=u_bad+phi*v(1,:)*odf; % set bad value (1xE)
        v_good=reshape(max(u_good+repmat(v*betP,1,B)),E,B)'; % good value is the max for different b_p choices [BxE]
        D=bsxfun(@gt,v_bad,v_good); % default = 1 if vbad > vgood
        [~,i]=find(D); % find where default occurs (D !=0)
        v_good(D)=v_bad(i); % when you default, replace vg with vb
        errV=max(max(abs(v_good./v-1))); % evaluate the error
        v=v_good; % update value
    end
    errD=sum(D(:)~=D_old(:)); % error = sum the number of times D unequal to D_old
    fprintf('error in D =%g\n',errD)
    if errD==0; dvmin=0; end % if D has converged, set dvmin = 0 to end the big while loop 
end,toc

%Below: I'm defining d_pos to capture both the index of the debt stance
%within state matrix and also the default decision.
% Thus (d_pos = 0 if default,
%       else d_pos = index within debt space b of current debt level)
[~,d_pos]=max(u_good+repmat(v*betP,1,B)); % get the debt position of max values (i.e. index of debt stance where value is maximized)
d_pos=reshape(d_pos,E,B)'; d_pos(D)=0; % set debt position to 0 for default, leave it at whatever other value it was for no default.
save('init_guess','D','v') % save updated v as initial guess
realized_debt=reshape(b(sum(~D)),1,E); % the realized debt choices w/o default
le=log(e); % get log of shock process
E_med = round(E/2); % get median value of shock (for use in graphs and effects at median) 

figure(1), plot(realized_debt,le,'r','linewidth',2)
title('Default set'),xlabel('Debt'),ylabel('log TFP')

figure(2),hold on,plot(b,q(:,E_med),'Color','b','linewidth',2), title('Bond price at median TFP'),xlabel('Debt')
% takes 3 min
figure(3), mesh(Z, b, q), title('Bond price as function of debt and productivity'),xlabel('Debt'), ylabel('log TFP')

%% Simulation
T=500; % total number of periods in simulation including burn-in
Ts=400; % number of periods in simulations minus burn-in
smooth=1600; %the lambda smoothing parameter for HP filter
n_sim=2000; % number of simulations
num_var=8; % number of variables
sim_means=nan(n_sim,num_var); % means of simulated variables
sim_var=nan(n_sim,num_var);  % variances of simulated variables
sim_corr=nan(n_sim,7); % correlations of simulated variables
historical=nan(n_sim,3); %% called 'historical' because it refers to the 'historical default-output comovement' from MY.
Y_def=[]; % all our variables around (equal periods before and after) default; for all simulations
debtmax=12; %debt upper bound levels for "before-and-after default" window
debt_window=-debtmax:debtmax; % debt levels for "before-and-after default" window
F=cumsum(P); %take a cumulative Markov probability in order to determine Markov chain of TFP shocks
for sim=1:n_sim
    Y=nan(T,num_var); % variables vector
    def_hist=false(T,1); %default history, initialized all as false (no default)
    reentry_hist=def_hist; %reentry history, initialzed all as false (no reentry) - will be set in a second.
    H=nan(T,3); % default, rehab & state history gathered in one matrix
    d=false; i=1; j=E_med; % initial states (index of default, debt and TFP shock respectively)
    tfp_index=rand(T,1); % draw TFP indexes, they will be used to compute the chain of TFP draws at end of loop
    reentry=rand(T,1)<phi; % draw reentry 
    for t=1:T
        running_index=d_pos(i,j); % index of default for this period
        if running_index==0||d % if index is zero, i.e. there is default or if there was default yesterday, there's default today
            if ~d % if yesterday there was no default, change state d to default since today we're defaulting.
                d=true; 
                def_hist(t)=d; % and add it to default history
            end 
            R=nan; % also, set all variables to their default values...
            GDP=gdp(2,j); 
            TB=xi*log(e(j))*GDP;
            MS=ms(2,j);
            IM=M(2,j);
            L_=L(2,j);
            running_index=i; %... and update the running index.
        else %If there's no default today, set variables to their good values
            R=1/q(running_index,j)^4-r^4; % annual sovereign bond spread
            GDP=gdp(1,j); % real GDP
            TB=b(i)-b(running_index)*q(running_index,j)+xi*log(e(j))*GDP; % trade balance
            MS=ms(1,j); % imported intermediate inputs
            IM=M(1,j); % total intermediate goods
            L_=L(1,j); % labor
        end
        CONS=GDP-TB; % consumption
        Y(t,:)=[GDP CONS R TB/GDP L_ IM MS b(i)/GDP]; % gather all variables in one vector
        H(t,:)=[d i j]; % record the current state in the history vector
        % For next period:
        if d && reentry(t) % If we can reenter markets tomorrow, then
            d=false; % set the default indicator for false (so that tomorrow it's possible not to default)
            reentry_hist(t)=true; % add the reentry to credit markets to reentry history
            running_index=1;  %and change running index. 
        end 
        j=find(tfp_index(t)<F(:,j),1); % update TFP index to get draw for tomorrow using Markov chain
        i=running_index; %update the debt position of tomorrow according to how we updated the running index (which depended on whether we default or not, and whether we reenter or not)
    end
    Y(:,[1:2 6:7]) =log(Y(:,[1:2 6:7])); %take logs for variables for which it makes sense
    Y(:,[1 2 4 6 7])=hpfilter_lg(Y(:,[1 2 4 6 7]),T,smooth); % invoke HP filter (MY do too so I'm following them)
    %Below: construct the matrix of variable values before and after default.
    default_index=bsxfun(@plus,find(def_hist(T-Ts+1:T))+T-Ts,debt_window)'; %get the time periods around default (as indexes of a window), and add them to the debt level 
    Y_def_sim=nan(size(default_index,1)*size(default_index,2),num_var+2); % initialize vector to be size of default occurances x number of variables plus 2 b/c we'll add the history of default and reentry too
    di=default_index>=1&default_index<=T; %get all the indexes that are between 1 and T
    default_index=default_index(di);
    Y_def_sim(di,:)=[Y(default_index,:) def_hist(default_index) reentry_hist(default_index)]; % vector of variables around times of default (in a window before and after); for this simulation only
    Y_def=[Y_def; Y_def_sim]; % in each loop, I add the variables of this simulation, so this matrix expands in each loop.
    %after the loop, the size of this matrix is (number of default occurences) x (number of variables)
    sim_means(sim,:)=nanmean(Y(T-Ts+1:T,:));
    sim_var(sim,:)=nanvar(Y(T-Ts+1:T,:));
    CC=nancov(Y(T-Ts+1:T,1:6))./sqrt(sim_var(sim,1:6)'*sim_var(sim,1:6));
    sim_corr(sim,:)=[CC(1,3:6) CC(3,4:6)];
    CC=corrcoef([Y(T-Ts+1:T,1) def_hist(T-Ts+1:T)]);
    autocorr_GDP=corrcoef(Y(T-Ts+1:T-1,1),Y(T-Ts+2:T,1)); % autocorr GDP
    historical(sim,:)=[CC(2) mean(def_hist(H(:,2)>1)) autocorr_GDP(2)];
end
Y_def=permute(reshape(Y_def,2*debtmax+1,size(Y_def,1)/(2*debtmax+1),num_var+2),[1 3 2]); % reshape this matrix so that it now is (number of debt levels) x (number of variables) x (number of defaults per each debt level) --> so that I can take means across all simulations
Y_def_means=nanmean(Y_def,3); %take means along 3rd dimension, i.e.  we get means for all variables across all simulations around times of default
%% Table III
Y=mean(sim_means); 
sim_var=sqrt(mean(sim_var)); 
sim_corr=mean(sim_corr); 
historical=nanmean(historical);
fprintf('Average debt/GDP ratio %.2f%%\n',Y(8)*100) %
fprintf('Average bond spreads %.2f%%\n',Y(3)*100) %
fprintf('Std. dev. of bond spreads %.2f%%\n',sim_var(3)*100) %
fprintf('Consumption std.dev./GDP std.dev. %.2f\n',sim_var(2)/sim_var(1))%
fprintf('Correlations with GDP\n')
fprintf('   bond spreads %.2f\n',sim_corr(1))%
fprintf('   trade balance %.2f\n',sim_corr(2))%
fprintf('   labor %.2f\n',sim_corr(3))%
fprintf('   intermediate goods %.2f\n',sim_corr(4)) %
fprintf('Correlations with bond spreads\n') 
fprintf('   trade balance %.2f\n',sim_corr(5)) %
fprintf('   labor %.2f\n',sim_corr(6)) %
fprintf('   intermediate goods %.2f\n',sim_corr(7)) %
fprintf('Historical default-output comovement\n')
fprintf('   correlation between default and GDP %.2f\n',historical(1)) %
fprintf('   fraction of defaults with GDP below trend %.2f%%\n',mean(Y_def(debtmax+1,1,:)<0)*100) %
fprintf('   fraction of defaults with large recessions %.2f%%\n',mean(Y_def(debtmax+1,1,:)<-2*sim_var(1))*100) %where GDP is less than 2 variances below trend
fprintf('Output drop in default %.2f%%\n',(Y_def_means(debtmax+1,1)-Y_def_means(debtmax,1))*100) %to be deleted

%% Figure VI
figure(4),titles={'GDP','Consumption','Interest rate','Trade balance/GDP','Labor','Intermediate goods','Imported intermediate goods','Debt/GDP'};
for i=1:num_var
    subplot(2,4,i),hold on
    plot(debt_window,Y_def_means(:,i),'r-','LineWidth',2,'Color','k')
    set(gca,'XTick',-debtmax:4:debtmax)
    set(gca,'XTickLabel',-debtmax/4:debtmax/4)
    title(titles{i}),xlabel('year')
    axis([-debtmax debtmax -inf inf]),grid on
end
