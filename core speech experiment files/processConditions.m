function [output,fs] = processConditions(input,fs,condition,totalConditions,includeTraining,includePreTest)
%ENVOY_CONDITIONS This is where conditions are defined. Passes signal to
%appropriate vocoder function.
persistent allConditions
% Important -- you must also change "totalConditions" in
% "generateSentenceLists.m"

%manually define parameters here and any custom signal processing at the
%bottom of this function

%% Static Parameters: These wont change based on condition and dont need to be accounted for
nElectrodes = 16;
carrierDensity = 1;
carrierLo = 250;
carrierHi = 16000;
currentSpread = -12;

conditionDebug = 0;


%% Dynamic parameters: add each dynamic parameter to the expPar structure with its own field name
expPars = struct(...
'dynamicRange',[Inf 40],...
'freqShift',[0 5],...
'noiseSNR',[5 10 Inf]);


%% calculate all combinations of all dynamic parameters into total number of conditions
expParNames = fields(expPars);
if totalConditions~= 0
    totalConditions = 1;
end
for i = 1:length(expParNames)
    expParSize(i) = length(expPars.(expParNames{i}));
    totalConditions = totalConditions*expParSize(i);
end

if isempty(allConditions) % calculate the full matrix of all conditions if it hasnt been done yet for this experiment. 
    %These are not randomized so its safe to re-run between sessions.
    for param = 1:length(expParNames)
        allConditionValues = [];
        if param == length(expParNames)
            nReps = 1;
        else
            nReps = prod(expParSize(param+1:end));
        end

        for rep = 1:nReps
            tempMatrixIndex = 1:expParSize(param);
            if param == 1;
                nInnerReps = 1;
            else
                nInnerReps = prod(expParSize(1:param-1));
            end
            for i = 1:length(tempMatrixIndex)
                allConditionValues = [allConditionValues; repmat(tempMatrixIndex(i),nInnerReps,1)];
            end
        end
        allConditions = [allConditions allConditionValues];
    end
end
%% process stimuli according to which condition is passed to
if size(input,1) > 1
    input = input';
end  

if condition <= totalConditions
    dynamicRange = expPars.dynamicRange(allConditions(condition,1));
    freqShift = expPars.freqShift(allConditions(condition,2));
    noiseSNR = expPars.noiseSNR(allConditions(condition,3));
    
    if allConditions(condition,3) == Inf
        noise = zeros(size(input));   
    else
        noiseData = load('SSN_big.mat');  % this SSN previously used with IEEE sentences
        noise = noiseData.z;
        
        maxValidStartIndex = (length(noise)-length(input))-1;
        noiseRange = [1:length(input)]+maxValidStartIndex;
        noise = noise(noiseRange);
        % rms scale the noise to produce SNR specified in dynamic
        % parameters
        noise = (rms(input)/rms(noise)).*noise./(10^(noiseSNR/20));       
    end
    % run signal and noise through vocoder with combination of static and
    % dynamic parameters    
    output = spiral(input+noise,nElectrodes,carrierDensity,carrierLo,carrierHi,currentSpread,...
        dynamicRange,...
        freqShift,...
        fs);
    
    if conditionDebug
        clc
        disp(['Dynamic Range: ' num2str(dynamicRange)])
        disp(['Frequency Shift: ' num2str(freqShift)])
        disp(['SNR: ' num2str(noiseSNR)])
    end
    
elseif condition == totalConditions+1 % this condition can happen if training is enabled, but if training is not enabled then produce an error message
    %% Training block, by default this prsents clear and vocoded speech in quiet.
    if includeTraining == false && includePreTest == false
        error(['Condition ' num2str(condition) ' passed to script, but combination of defined variables produces only ' num2str(totalConditions) ' total conditions. Make sure totalConditions specified in generateSentenceLists is correct and check your dynamic parameters defined above in this script.']);
    elseif includeTraining == true
        vocodedInput = spiral(input,nElectrodes,carrierDensity,carrierLo,carrierHi,currentSpread,...
            Inf,...
            0,...
            fs); 
        
        vocodedInput2 = spiral(input,nElectrodes,0,carrierLo,carrierHi,currentSpread,...
            Inf,...
            0,...
            fs); 
        
        output = [input'; zeros(fs,1); vocodedInput;]; % for the training conditions play both the vocoded 
%         output = [vocodedInput; vocodedInput2]; % for the training conditions play both the vocoded
    elseif includePreTest == true;
        % NYI. TODO add pretest processing.
    end
elseif condition == totalConditions+2  % pretest condition if both training and pretest are defined.
    if includeTraining == false && includePreTest == false
        error(['Condition ' num2str(condition) ' passed to script, but combination of defined variables produces only ' num2str(totalConditions) ' total conditions. Make sure totalConditions specified in generateSentenceLists is correct and check your dynamic parameters defined above in this script.']);
    else
        % define the pretest signal processing here.
        output = spiral(input,nElectrodes,1,carrierLo,carrierHi,-12,...
            Inf,...
            0,...
            fs); 
    end
    
else% condition number is greater than max possible condition, throw an error telling user to ensure 
    %matching configuration between this script and generateSentenceLists
    error(['Condition ' num2str(condition) ' passed to script, but combination of defined variables produces only ' num2str(totalConditions) ' total conditions. Make sure totalConditions specified in generateSentenceLists is correct and check your dynamic parameters defined above in this script.']);
    
end



end