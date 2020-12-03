function speechExperiment(id,app,varargin)
%% docstring goes here

%% Static definitions
includeTraining = true;
numConditions = 12;
speechCorpus = 'IEEE';   % expectedCorpusNames = {'AzBio','IEEE','Presto','Hint','NS','custom'};
experiment.htmlDebug = 0;

htmlSource = '/web/catss/Audio/webAudioPlayer.html';       % for use on MLWA Server
% htmlSource = 'C:\Audio\webAudioPlayer.html';                         % local testing
% htmlSource = 'C:\Users\Jbeim\OneDrive\Documents\MATLAB\local scripts\Online Experiments\webAudioPlayer.html';

experiment.writePath = '/web/catss/Audio/';                      % for use on MLWA Server
% experiment.writePath = 'C:\Audio\';                       % local testing
% experiment.writePath = 'C:\Users\Jbeim\OneDrive\Documents\MATLAB\local scripts\Online Experiments\';

experiment.sourcePath = ['/web/catss/Audio/Speech/' upper(speechCorpus) '/'];        % for use on MLWA Server
% experiment.sourcePath = 'C:\Users\Jbeim\OneDrive\Documents\MATLAB\local scripts\Online Experiments\Jackson Speech\IEEESent\';                   % local testing


% dataPath = '/labs/oxenhamlab/Speech/';                     % for use on MLWA Server
% dataPath = 'C:\Users\Jbeim\OneDrive\Documents\MATLAB\local scripts\Online Experiments\Jackson Speech\SentenceSubjects\';                           % local testing
dataPath = '/labs/oxenhamlab/ASADemo2/';


%% parse inputs, assign optional parameters
p = inputParser;


experiment.subjectFile = [dataPath id '.mat']; % path to the subject datafile

if ~isfile(experiment.subjectFile)
    generateSentenceLists(dataPath,id,numConditions,'corpusname',speechCorpus,'includeTraining',includeTraining); % initialize a new data structure if no existing file is found
end

load(experiment.subjectFile)

experiment.completed = 0;
trackerMsg = ['List ' num2str(subject.listIndex) ' of ' num2str(length(subject.listOrder))];
sourceFile = [experiment.sourcePath num2str(subject.nextList) '_' num2str(subject.nextSentenceOrder(subject.sentenceIndex)) '.WAV'];
% disp(sourceFile)
% dir(experiment.sourcePath)

[source, fs] = audioread(sourceFile);
[experiment.audiodata,experiment.fs] = processConditions(source,fs,subject.nextCondition,includeTraining);

experiment.includeTraining = includeTraining;
experiment.numConditions = numConditions;
experiment.speechCorpus=speechCorpus;

if experiment.includeTraining == true;
    experiment.textData = load('IEEEsent_Text.mat');
    experimentInitialInstructionText = {'This is a training trial.','Press play above and listen to the normal and', 'vocoded speech while reading along with the','text below. You do not need to enter a reponse.','Press "Save Response" to proceed.'};
else
    experimentInitialInstructionText = {'Press "Play" above, then enter as much of','the sentence as possible below using only','letters a-z (no punctuation or special','characters) then press "Save Response."'};
end


setappdata(app,'experiment',experiment)
setappdata(app,'subject',subject)


%% Clear the gui, build necessary elements
guiFigure = app;
% guiFigure.Color = [.75 .75 .75]
previousFigElements = guiFigure.Children;
delete(previousFigElements)




windowSize = repmat(app.Position(3:4),1,2);


figureElements.webAudioPlayer = uihtml...
    ('Parent',guiFigure,...
    'HTMLSource',htmlSource,...
    'Interruptible','off',...
    'Position',[0.01 0.8333 1.0000 0.1667].*windowSize,...,
    'DataChangedFcn',@(src,event)webAudioChange(src,event)...
    );

if ~experiment.htmlDebug 
    figureElements.webAudioPlayer.Visible = 'off';
end


 % dirty initialization, using afc_sound('init') doesnt work because the html is added later
drawnow;
pause(.1)
if isempty(figureElements.webAudioPlayer.Data)
    figureElements.webAudioPlayer.Data = {-1};
    drawnow;
    waitfor(figureElements.webAudioPlayer,'Data',0);
    disp('init success')
end

% answer field
figureElements.responseInputField = uieditfield(guiFigure,'text',...
    'Position',[.17 .35 .65 .07].*windowSize,...
    'Enable','off',...
    'FontSize',20,...
    'HorizontalAlignment','center',...
    'ValueChangedFcn',@(app,event) inputResponseCallback(app,event));
% play button

figureElements.playButton = uibutton(guiFigure,'push',...
    'Position',[.36 .71 .278 .14].*windowSize,...
    'FontSize',20,...
    'Text','Play',...
    'ButtonPushedFcn',@(app,event) playButtonCallback(app,event));
% save response button

figureElements.saveButton = uibutton(guiFigure,'push',...
    'Position',[.227 .14 .228 .14].*windowSize,...
    'FontSize',20,...
    'Text','Save Response',...
    'Enable','off',...
    'ButtonPushedFcn',@(app,event) saveButtonCallback(app,event));
% exit button

figureElements.exitButton = uibutton(guiFigure,'push',...
    'Position',[.545 .14 .228 .14].*windowSize,...
    'FontSize',20,...
    'Text','Exit',...
    'ButtonPushedFcn',@(app,event) exitButtonCallback(app,event));
% progress text field

figureElements.progressText = uilabel(guiFigure,...
    'Position',[.773 .781 .183 .073].*windowSize,...
    'Text',trackerMsg,...
    'HorizontalAlignment','center',...
    'FontSize',18);
% message text field

figureElements.messageText = uilabel(guiFigure,...
    'Position',[.318 .44 .365 .057].*windowSize,...
    'Text','',...
    'HorizontalAlignment','center',...
    'FontSize',18);
% instruction text

figureElements.instructionText = uilabel(guiFigure,...
    'Position',[.3 .497 .383 .14].*windowSize,...
    'Text',experimentInitialInstructionText,...
    'HorizontalAlignment','center',...
    'FontSize',18);

% invisible (unless debugging) html audio player for web based playback



setappdata(app,'figureElements',figureElements);

end

function inputResponseCallback(app,event)
setappdata(app.Parent,'currentResponse',event.Value)
end

function playButtonCallback(app,event)
% start by configuring states of buttons and text entry
figureElements = getappdata(app.Parent,'figureElements');
figureElements.playButton.Enable = 'off';
figureElements.exitButton.Enable = 'off';
figureElements.responseInputField.Enable = 'on';
drawnow;

subject = getappdata(app.Parent,'subject');


% grab processed audio and play
experiment = getappdata(app.Parent,'experiment');




audioFileName = [subject.id '_' num2str(subject.nextList) '_' num2str(subject.nextSentenceOrder(subject.sentenceIndex)) '.wav'];
audiowrite([experiment.writePath audioFileName],experiment.audiodata,experiment.fs);

experiment.trialStartTime = tic;
figureElements.webAudioPlayer.Data = {0,audioFileName};                     % stage audio file within HTML
waitfor(figureElements.webAudioPlayer,'Data',1);                            % wait for html to confirm ability to play through entire file

if experiment.includeTraining == true
    if subject.nextCondition == experiment.numConditions+1
        %this is the training case
        textInd = (subject.nextList-1)*size(subject.listwiseSentenceOrder,2)+subject.nextSentenceOrder(subject.sentenceIndex);
        displayText = experiment.textData.IEEEsent{textInd};
        displayText = strrep(displayText,'''',''); % remove punctuation from text
        displayText = strrep(displayText,'"','');
        
        figureElements.responseInputField.Value = lower(displayText);
    else
        figureElements.instructionText.Text = {'Press "Play" above, then enter as much of','the sentence as possible below using only','letters a-z (no punctuation or special','characters) then press "Save Response."'};
        % do what we normally do
    end
end


figureElements.webAudioPlayer.Data = {2};                                   % Send start playback command

% while sound is playing, process the sentence
if subject.sentenceIndex == size(subject.listwiseSentenceOrder,2)        % end of list of sentences
    if subject.listIndex < length(subject.listOrder)                        % if this is not last list, initialize the next list of sentences
        subject.listIndex = subject.listIndex+1;
        subject.nextList = subject.listOrder(subject.listIndex);
        subject.nextCondition = subject.conditionOrder(subject.listIndex);
        subject.nextSentenceOrder = subject.listwiseSentenceOrder(subject.listIndex,:);
        subject.sentenceIndex = 1;
        trackerMsg = ['List ' num2str(subject.listIndex) ' of ' num2str(length(subject.listOrder))];
        figureElements.progressText.Text = trackerMsg;
    else                                                                    % if it is the last list, mark the experiment as complete
        experiment.completed = 1;
    end
else                                                                        % not the end of a list, increment index and continue
    subject.sentenceIndex = subject.sentenceIndex+1;
    figureElements.messageText.Text = '';
end

% load new source and process
% disp(subject.sentenceIndex)
% disp([experiment.sourcePath num2str(subject.nextList) '_' num2str(subject.nextSentenceOrder(subject.sentenceIndex)) '.WAV'])

[source, fs] = audioread([experiment.sourcePath num2str(subject.nextList) '_' num2str(subject.nextSentenceOrder(subject.sentenceIndex)) '.WAV']);
[experiment.audiodata,experiment.fs] = processConditions(source,fs,subject.nextCondition,experiment.includeTraining);

% if preprocessing finishes before sentence is done playing, wait for sentence to complete playback.
waitfor(figureElements.webAudioPlayer,'Data',4)

% log audio completion time, % we can add an extra allowance for response
% time after the study completes
if isfield(subject,'ElapsedTrialTimeSeconds')
    subject.ElapsedTrialTimeSeconds = [subject.ElapsedTrialTimeSeconds; toc(experiment.trialStartTime)];
else
    subject.ElapsedTrialTimeSeconds = toc(experiment.trialStartTime);
end

experiment.responseStartTime = tic;
% update the data structures for the subject and experiment
setappdata(app.Parent,'subject',subject)
setappdata(app.Parent,'experiment',experiment)

% clean up the audio file for this trial and enable the response save
% button
delete([experiment.writePath audioFileName])
figureElements.saveButton.Enable = 'on';
setappdata(app.Parent,'figureElements',figureElements);
end

function saveButtonCallback(app,event)
        figureElements = getappdata(app.Parent,'figureElements');
        figureElements.saveButton.Enable = 'off';
        drawnow;

        experiment = getappdata(app.Parent,'experiment');
        subject = getappdata(app.Parent,'subject');
        
        figureElements.responseInputField.Enable = 'off';
        figureElements.responseInputField.Value = '';
        
        % keep track of additional time before participant saves their
        % response (for computing an average, not necessarily for payment)
        if isfield(subject,'responseTimeSeconds')
            subject.responseTimeSeconds = [subject.responseTimeSeconds; toc(experiment.responseStartTime)]; 
        else
            subject.responseTimeSeconds = toc(experiment.responseStartTime);
        end

        currentResponse = getappdata(app.Parent,'currentResponse');
        previousResponses = subject.responses;
        subject.responses = [previousResponses; {currentResponse}];
        save(experiment.subjectFile,'subject') % added saving every response instead of every list
                
        if subject.sentenceIndex == 1  
%             save(experiment.subjectFile,'subject')
            figureElements.messageText.Text = 'End of list.';
            figureElements.playButton.Enable = 'on';
            figureElements.exitButton.Enable = 'on';
%             uicontrol(figureElements.playButton);            
        elseif experiment.completed % experiment is complete, only allow exit button
            figureElements.messageText.Text = 'End of experiment. Please press the exit button to quit.';
            figureElements.playButton.Enable = 'off';
            figureElements.exitButton.Enable = 'on';
%             uicontrol(figureElements.exitButton);
        else % just a new sentence
%              figureElements.messageText.Text = '';
            figureElements.playButton.Enable = 'on';
            figureElements.exitButton.Enable = 'off';
%             uicontrol(figureElements.playButton);
        end
        
        setappdata(app.Parent,'currentResponse','');
        setappdata(app.Parent,'subject',subject);
end

function exitButtonCallback(app,event)
subject = getappdata(app.Parent,'subject');
experiment = getappdata(app.Parent,'experiment');
save(experiment.subjectFile,'subject')
close(app.Parent)
end