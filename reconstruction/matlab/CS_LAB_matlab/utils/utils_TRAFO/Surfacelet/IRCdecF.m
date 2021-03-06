%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%	SurfBox-MATLAB (c)
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%%	Yue Lu and Minh N. Do
%%
%%	Department of Electrical and Computer Engineering
%%	Coordinated Science Laboratory
%%	University of Illinois at Urbana-Champaign
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
%%
%%	IRCdecF.m
%%	
%%	First created: 08-14-05
%%	Last modified: 04-13-06
%%
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%


function subband =IRCdecF(subband, K, level, Hflts)

%   Iteratively Resampled Checkerboard Filter Bank Decomposition (Fourier
%   Domain Implementation)
%
%   *****  INPUT:  *****
%
%   subband: N-dimensional (N >= 2) input signal in the FREQUENCY domain.
%
%   K: channel index, 1 <= K <= N
%
%   level: a row vector specifying the decomposition levels for each pair
%   of dimensions. Note: only level(m) for m ~= k will be used.
%
%   Hflts: A cell array containing two decomposition checkerboard filters
%   {H0, c0, H1, c1}  
%
%   *****  OUTPUT:  *****
%
%   subband: N-D output signal in the FREQUENCY domain.
%



%% dimension of the problem
N = ndims(subband);

%% check parameter validity
if (length(level) ~= N) | (K > length(level)) ...
        | (sum(level < 0) ~= 1) | (level(K) >= 0)
    error('Input parameter LEVEL is not valid.');
end

    
%% prepration
szS = size(subband);

%% make sure the dimension is correct
if any(mod(szS, 2 .^ level))
    error('Size error! Try reducing the number of decomposition levels.');
end

szH0 = size(Hflts{1}); szH1 = size(Hflts{3});
szFlt = max(szH0, szH1);

%% Subscript cell array
subary = repmat({':'}, [2 N]);

%% preallocate the memory for a temp variable
subtmp = repmat(complex(0), szS);

%% start working
for m = 1 : N  %% N is a small number like 2,3, or 4.
    
    %% We work on pairs of dimensions: (K,1), (K,2), ... (K, N)
    if m == K   %% except on dimensions (K, K)
        continue;
    end
    
    %% Size of the 2-D slice
    ftSpat = zeros((szS(K)-1) * 2, szS(m)); %% get the full length along K
    
    %% This one is ``thinner'' in the m dimension. This will reduce
    %% the number of filter resampling (shearing) operations.
    ftSpatSml = zeros((szS(K)-1) * 2, szFlt(2)); 
    
    indm = [1: szS(m)];
    
    %% This variable is what we actually use to multiply with the subband
    ftSlice = repmat(complex(0), [szS(K), szS(m)]);
    
    %% IRCdec on dimensions (K, m)
    for le = 1 : level(m) %% Another small number, like 0, 1, 2, 3
        
        if any(size(ftSpat) < szFlt)
            error('Image size is smaller than the filter size (from downsampling). Try using more compact filters.');
        end
        
        %% select the suitable column indices
        selcol = mod(floor( (indm - 1) / (szS(m) / 2^le) ), 2) == 0;
        subary{1,m} = indm(selcol);
        subary{2,m} = indm(~selcol);
        
        for chan = 0 : 1    %% Two channels
            
            %% Get the decomposition filter
            %% Note: we scale the filter coefficients (a small 2-D array)
            %% by 0.5. By doing this, we avoid having to scale the
            %% large N-D array by 0.5 in the downsampling stage.
            H = Hflts{2*chan + 1} ./ 2;  
            ctr = Hflts{2*chan + 2};
            szH = size(H);
            
            %% To get back to the original K-m dimension, since ftSlice
            %% might have been transposed.
            ftSlice = reshape(ftSlice, [szS(K), szS(m)]);
            
            if le == 1
                %% Get the FFT of filters
                ftSpat(:) = 0;
                ftSpat(1:szH(1), 1:szH(2)) = H;
                ftFreq = fft2(circshift(ftSpat, 1 - ctr));
                 %% Remove the complex conjugate symmetric part
                ftSlice = ftFreq(1:szS(K), :);
            else
                %% We will resample the checkerboard filters before filtering. 
                %% This has the advantage of carrying out the resampling 
                %% operation on 2-D filters instead of on N-D signals. Also by 
                %% doing this, we do not need to have backsampling at the end.
                
                nsubs = 2^(le - 1); %% number of subbands 
                tmp_sub = [1 : szS(m) / nsubs]; %% a set of subscripts
                
                for n = 0 : nsubs - 1
                    %% Get the shearing factor (SF)
                    sf = nsubs - 1 - 2 * n;
                                        
                    %% After shearing, the filter H becomes ``taller''. We need
                    %% to make sure that we can still handle this filter
                    %% size.
                    if size(ftSpatSml, 1) < (szH(1) + abs(sf)* (szH(2)-1))
                        error('Image size is smaller than the filter size (from shearing). Try using more compact filters.');
                    end
                    
                    %% load the filter
                    ftSpatSml(:) = 0;
                    ftSpat(:) = 0;
                    if sf > 0
                        ftSpatSml(1:szH(1), 1: szH(2)) = H;
                        newctr = [ctr(1) + sf * (ctr(2)-1), ctr(2)];
                    else
                        ftSpatSml(end-szH(1)+1:end, 1: szH(2)) = H;
                        newctr = [size(ftSpatSml, 1) + ctr(1) - szH(1) + sf * (ctr(2)-1), ctr(2)];
                    end
                    
                    %% resample the filter in the spatial domain
                    ftSpatSml = resampc(ftSpatSml, (3 + sign(sf))/2, abs(sf), 'per');
                    
                    
                    ftSpat(:, 1:size(ftSpatSml, 2)) = ftSpatSml;
                    ftFreq = fft2(circshift(ftSpat, 1 - newctr));
                    ftSlice(:, tmp_sub) = ftFreq(1:szS(K), :);
                  
                    tmp_sub = tmp_sub + szS(m) / nsubs;
                end
                
            end
            
            if K > m
                ftSlice = ftSlice .';
            end
                        
            %% Pointwise multiplication of Filters and Input Data
            sz = ones(1, N);
            sz([K,m]) = szS([K,m]);
            
            ftSlice = reshape(ftSlice, sz);
            subtmp = subband .* repmat(ftSlice, szS ./ sz);

            %% Downsampling by 2 along dimension m
            if chan == 0
                sub0 = subtmp(subary{1,:}) + subtmp(subary{2,:});
            else
                sub1 = subtmp(subary{1,:}) + subtmp(subary{2,:});
            end
            
        end  %% chan = 0:1
        
        %% Save the data
        subband(subary{1,:}) = sub0;
        subband(subary{2,:}) = sub1;
         
       %% Reduce the size of the 2-D slice along dimension m
       ftSpat = ftSpat(:, 1:end/2);
       
    end %% le = 1 : level(m)
    
    %% We will work on the next dimension.
    subary{1, m} = ':'; subary{2,m} = ':';
end
        
%%	This software is provided "as-is", without any express or implied
%%	warranty. In no event will the authors be held liable for any 
%%	damages arising from the use of this software.
