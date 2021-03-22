function [subject] = generateSentenceLists(dataPath,id,varargin)
% This code initializes a new data file when speechExperiment is first run.

% Pre-built subject structure needs:
%- ".nextList" 1-72
%- ".listOrder" L-length vector of numbers 1-72
%- ".nextGender" 0 (female) or 1 (male)
%- ".genderOrder" L-length vector of 1s and 0s
%- ".nextSentenceOrder" permutation of 10
%- ".listwiseSentenceOrder" L-by-10 matrix of permutations of 10.
%- ".nextNoise" 0 (quiet) or 1 (noise)
%- ".noiseOrder" L-length vector of 1s and 0s
%- ".listIndex" 1-L
%- ".id" Subject initials (string)
%- ".responses" Should start out as an empty cell, = {}.

p = inputParser;

rng('shuffle') % get a new seed for random number generation

defaultListsPerCondition = 3;
defaultMaxLists = 23;
defaultSentencesPerList = 20;
defaultCorpusName = 'custom';
defaultTraining = false;
defaultPreTest = false;
expectedCorpusNames = {'AzBio','IEEE','Presto','Hint','NS','custom'};

validPositiveScalar = @(x) isnumeric(x) && isscalar(x) && (x > 0);
addRequired(p,'dataPath')
addRequired(p,'id')
addRequired(p,'totalConditions',@(x) isnumeric(x) && isscalar(x));
addParameter(p,'maxLists',defaultMaxLists,validPositiveScalar)
addParameter(p,'sentencesPerList',defaultSentencesPerList,validPositiveScalar);
addParameter(p,'corpusName',defaultCorpusName,@(x) any(validatestring(x,expectedCorpusNames)));
addParameter(p,'listsPerCondition',defaultListsPerCondition,validPositiveScalar);
addOptional(p,'includeTraining',defaultTraining,@(x) islogical(x))
addOptional(p,'includePreTest',defaultPreTest,@(x) islogical(x))

parse(p,dataPath,id,varargin{:});

if p.Results.includeTraining == true && p.Results.includePreTest == true
    totalConditions = p.Results.totalConditions+2;
elseif xor(p.Results.includeTraining == true,p.Results.includePreTest == true)
    totalConditions = p.Results.totalConditions+1;
else
    totalConditions = p.Results.totalConditions;
end




subject.corpusName = p.Results.corpusName; % save the corpus name

switch lower(p.Results.corpusName)  % TODO: add correct values for non azbio materials
    case 'azbio'
        maxListNumber = 23;
        sentencesPerList = 20;
    case 'bel'
        
    case 'hint'
        maxListNumber = 23;
        sentencesPerList = 20;
    case 'ieee'
        maxListNumber = 72;
        sentencesPerList = 10;
    case 'ns'
        maxListNumber = 32;
        sentencesPerList = 10;
    case 'presto'
        maxListNumber = 40;
        sentencesPerList = 9;
    case 'ieee_mod' % modified IEEE sentence list for chhayakants experiment.
        maxListNumber = 36;
        sentencesPerList = 10;
        
    otherwise
        maxListNumber = p.Results.maxLists;
        sentencesPerList = p.Results.sentencesPerList;
end

listsPerCondition = p.Results.listsPerCondition;

assert(listsPerCondition*totalConditions <= maxListNumber,...
    [num2str(listsPerCondition) ' lists x ' num2str(totalConditions) ' conditions requires ' num2str(listsPerCondition*totalConditions) ' lists. Only ' num2str(maxListNumber) ' lists are available.']);

if exist([p.Results.dataPath id '.mat'])%%     looks in current directory subfolder Subjects
    error('Subject ID already in use')
end



subject.id = id;
subject.responses = {};
requiredLists = listsPerCondition*totalConditions; % multiple of 3 (3 lists per block).
randomizedListOrder = randperm(maxListNumber); % from 23 AZBio sentences

subject.listOrder = randomizedListOrder(1:requiredLists); % Choose L number of lists
subject.listwiseSentenceOrder = nan(requiredLists,sentencesPerList); 

for i = 1:requiredLists
    subject.listwiseSentenceOrder(i,:) = randperm(sentencesPerList); % 20 comes from 20 sentences/list in AzBio.
end

% subject.genderord = nan(1,L);
% subject.noiseord = nan(1,L);
% for k = 1:(L/4)
%     noise_genders = [0 0 1 1; 1 0 1 0];
%     noise_genders_rand = noise_genders(:,randperm(length(noise_genders)));
%     subject.genderord((4*k-3):4*k) = noise_genders_rand(1,:);
%     subject.noiseord((4*k-3):4*k) = noise_genders_rand(2,:);
% end

if p.Results.includeTraining && p.Results.includePreTest
    subject.conditionOrder = reshape(repmat(randperm(requiredLists/listsPerCondition-2),[listsPerCondition 1]),[1 (requiredLists/listsPerCondition-2)*listsPerCondition]); % CHANGE THIS - randomize condition order
    subject.conditionOrder = [repmat(totalConditions-1,1,listsPerCondition) repmat(totalConditions,1,listsPerCondition) subject.conditionOrder(randperm(length(subject.conditionOrder)))];
elseif p.Results.includeTraining || p.Results.includePreTest
    subject.conditionOrder = reshape(repmat(randperm(requiredLists/listsPerCondition-1),[listsPerCondition 1]),[1 (requiredLists/listsPerCondition-1)*listsPerCondition]); % CHANGE THIS - randomize condition order
    subject.conditionOrder = [repmat(totalConditions,1,listsPerCondition) subject.conditionOrder(randperm(length(subject.conditionOrder)))];
else
    subject.conditionOrder = reshape(repmat(randperm(requiredLists/listsPerCondition),[listsPerCondition 1]),[1 requiredLists]); % CHANGE THIS - randomize condition order
    subject.conditionOrder = subject.conditionOrder(randperm(length(subject.conditionOrder)));
end
% Initializing - start with first list, first sentence, first condition.
subject.listIndex = 1;
subject.nextList = subject.listOrder(1);
% subject.nextgender = subject.genderord(1);
subject.nextSentenceOrder = subject.listwiseSentenceOrder(1,:);
% subject.nextnoise = subject.noiseord(1);
subject.nextCondition = subject.conditionOrder(1);


subject.sentenceIndex = 1;
save([p.Results.dataPath id '.mat'],'subject');
end