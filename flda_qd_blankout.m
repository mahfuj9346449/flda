function [W,theta] = fir_qd_blankout(XQ,XP,y,lambda)
% Function to run a feature-level domain adaptive classifier using a quadratic loss and a blankout transfer distribution.
% Input:    XQ      source data (M features x NQ samples)
%           XP      target data (M features x NP samples)
%           yQ      source labels (NQ x 1)
%           lambda  additional l2-regularization parameter
% Output:   W       Trained linear classifier
%           theta   parameters of the blankout transfer distribution
%
% Wouter M. Kouw
% Last update: 20-11-2015
% Check for solver
if isempty(which('minFunc')); error('Can not find minFunc'); end
options.DerivativeCheck = 'off';
options.Method = 'lbfgs';
options.Display = 'final';


% Shape
[M,N] = size(XQ);

% Number of classes
K = max(y);

% Check for vector y
if size(y,1)~=N; y = y'; end

if K==2
    
    % Check for y in {-1,+1}
    if ~isempty(setdiff(unique(y), [-1,1]));
        y(y~=1) = -1;
    end
    
    % Estimate dropout transfer parameters
    theta = est_transfer_params_blank(XQ,XP);

    % Second moment of transfer distribution
    VX = diag(theta./(1-theta)).*(XQ*XQ');

    % Least squares solution
    W = (XQ*XQ' + VX + lambda*eye(size(XQ,1)))\XQ*y;
    W = [W -W];
else
    
    W = zeros(M,K);
    theta = cell(1,K);
    for k = 1:K
        
        % Labels
        yk = (y==k);
        
        % 50up-50down resampling
        ix = randsample(find(yk==0), floor(.5*sum(1-yk)));
        Xk = [XQ(:,ix) repmat(XQ(:,yk), [1 floor((K-1)/2)])];
        yk = [double(yk(ix)); ones(1,floor((K-1)./2)*sum(yk))'];
        yk(yk==0) = -1;
        
        % Estimate dropout transfer parameters
        theta{k} = est_transfer_params_blank(Xk,XP);
        
        % Second moment of transfer distribution
        VX = diag(theta{k}./(1-theta{k})).*(Xk*Xk');

        % Least squares solution
        W(:,k) = (Xk*Xk' + VX + lambda*eye(size(Xk,1)))\Xk*yk;
        
    end

end

end

function [theta] = est_transfer_params_blank(XQ,XP)
% Function to estimate the parameters of a dropout transfer distribution

theta = max(0,1-mean(XP>0,2)./mean(XQ>0,2));

end