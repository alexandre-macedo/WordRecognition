function WordRecognition
%% Parameters

% Glogal variable -> Don't change this
global ZeroEnergy database CommandFlag CommandIndex TempLibrary RealTimeRunFlag
global CarCurrentPosition CarOldPosition GameRunning

% General
Fs=17100;
ZeroEnergy=0.005;
ZeroEnergyMax=0.1; % For calibration purposes only
WordEnergy=0.4;
CommandList={'Up', 'Down', 'Left', 'Right', 'Pause'};

%For Mel analysis
MelBlockLength=512;
MelBufferStep=171;
NFilter=26;
Coef=1:13;
MelLowerFreq=64;
MelUpperFreq=Fs/4; % Can't be bigger than Fs/2

% For Time warping

NormFactorType=2; % 1 -> No normalization factor = 1;
                  % 2 -> Sum of sizes. * Used for tests (Best Results?)
                  % 3 -> Size + Insertions

% For real time
BufferBlockLength=256;
QueueDuration=3;
BigBufferSizeT=10; % Time in seconds

% Maze
CarSpeed=5;
% Field
MazeFieldSize=[40,50];
SquareSize=20;
% Finish Line
FinishRows=[14,21];
FinishColumn=50;

% GUI
FigureTitle='ECE446: Word Recognition';
BackgroundColor = [1 1 1]; %White
GUIScale=0.8;


% Others
RealTimeRun=60;
ZeroCalibrationTime=5;
AudioInputDevice=-1; %Not working for real time

%% Initialzing values
%Other
CommandFlag = false;
CommandIndex = 1;
NumberOfCommands=length(CommandList);
RealTimeRunFlag = false;

%Filters
HamW=hamming(BufferBlockLength);
HamWMel=hamming(MelBlockLength);
MelFilterSize=MelBlockLength/2+1;
MelBank=MelFilterBank;


% Real Time related
RealTimeScore=zeros(1,NumberOfCommands);
BigBufferSize=round(BigBufferSizeT*Fs);
BufferVector=zeros(1,BigBufferSize);
BufferIndex=1;
WordFlag=false;

% Mel related
MelBufferOverlap=MelBlockLength-MelBufferStep;

% Statistical
nu=round(ZeroCalibrationTime*Fs/BufferBlockLength)-1;
[~,TCoef]=tstat(nu);

% Maze
UpdateRate=2*CarSpeed;
Field = CreateMazeField;
Graphic = CreateGraphic;
Car = CreateCar;

%% Initializing values GUI
ScreenS = get(0, 'ScreenSize');
ScreenX=ScreenS(3);
ScreenY=ScreenS(4);
FigureWidth=ScreenX*GUIScale;
FigureHeight=ScreenY*GUIScale;
FigurePositionX=(ScreenX-FigureWidth)/2;
FigurePositionY=(ScreenY-FigureHeight)/2;
msgScale=GUIScale/.8*.3;
SFont=FigureWidth/(0.6*1366)*8;
MFont=FigureWidth/(0.6*1366)*10;
BFont=FigureWidth/(0.6*1366)*14;
EBFont=FigureWidth/(0.6*1366)*16;

%% Creating gui
gui.handles.main = figure(...
    'Units', 'Pixels', 'Position',[FigurePositionX, FigurePositionY, FigureWidth, FigureHeight],...
    'NumberTitle','off',...
    'Toolbar','none',...
    'Resize','off',...
    'Menubar','none',...
    'DockControls','off',...
    'Color',BackgroundColor ,...
    'CloseRequestFcn',@CloseFigure,...
    'Name',FigureTitle);

uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.main, ...
    'String', '?', ...
    'BackgroundColor', BackgroundColor,...
    'Callback', @About,...
    'Units', 'Pixels', 'Units', 'Pixels', 'Position', [FigureWidth*0.96 FigureHeight*0.96 FigureWidth/25 FigureHeight/25],...
    'FontUnits','pixels','FontSize', MFont);

uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.main, ...
    'String', 'Restart', ...
    'Callback', @Restart,...
    'BackgroundColor', BackgroundColor,...
    'Units', 'Pixels', 'Position', [FigureWidth*0.96 FigureHeight*0.005 FigureWidth/25 FigureHeight/25],...
    'FontUnits','pixels','FontSize', SFont);

%% First Panel
gui.handles.panel(1)= uipanel('Units', 'pixels', ...
    'BorderWidth', 0, ...
    'Units', 'Pixels', 'Position', [0 0 FigureWidth FigureHeight], ...
    'Visible','on', ...
    'BackgroundColor', BackgroundColor);

% Display message
text={['--' FigureTitle '--'];...
    '';...
    'Choose one of the options below:'};

uicontrol('Style','text',...
    'Parent', gui.handles.panel(1),...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight/2 FigureWidth/2 FigureHeight*2/5],...
    'BackgroundColor',BackgroundColor,...
    'string', text, ...
    'HorizontalAlignment','center',...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(1)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(1), ...
    'String', 'Calibrate Zero Energy', ...
    'Callback', @CalibrateZero,...
    'Units','pixels',...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*5/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels',...
    'FontSize', BFont);

gui.handles.button(2)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(1), ...
    'String', 'Choose Library', ...
    'Callback', @ChooseLibrary,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*3/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(3)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(1), ...
    'String', 'Run RealTime', ...
    'Callback', @RealTimeTab,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*1/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

%% Second Panel
gui.handles.panel(2)= uipanel('Units', 'pixels', ...
    'BorderWidth', 0, ...
    'Units', 'Pixels', 'Position', [0 0 FigureWidth FigureHeight], ...
    'Visible','off', ...
    'BackgroundColor', BackgroundColor);

text={'--Library--';...
    '';...
    'Choose one of the options below:'};

uicontrol('Style','text',...
    'Parent', gui.handles.panel(2),...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight/2 FigureWidth/2 FigureHeight*2/5],...
    'BackgroundColor',BackgroundColor,...
    'string', text, ...
    'HorizontalAlignment','center',...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(4)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(2), ...
    'String', 'Load Library', ...
    'Callback', @LoadLibrary,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*5/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(5)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(2), ...
    'String', 'Record New Library', ...
    'Callback', @CreateNewLibrary,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*3/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(6)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(2), ...
    'String', 'Back', ...
    'Callback', @Back,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*1/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

%% Third Panel

gui.handles.panel(3)=uipanel('Units', 'pixels', ...
    'BorderWidth', 0, ...
    'Units', 'Pixels', 'Position', [0 0 FigureWidth FigureHeight], ...
    'Visible','off', ...
    'BackgroundColor', BackgroundColor);

text=['Press "Record", wait a couple of seconds for the recorder to initialize and say "' CommandList{CommandIndex} '".'] ;

gui.handles.RecordText=uicontrol('Style','text',...
    'Parent', gui.handles.panel(3),...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight/2 FigureWidth/2 FigureHeight*2/5],...
    'BackgroundColor',BackgroundColor,...
    'string', text, ...
    'HorizontalAlignment','center',...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(7)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(3), ...
    'String', 'Record', ...
    'Callback', @RecordCommand,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*5/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(8)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(3), ...
    'String', 'Next Command', ...
    'Callback', @NextCommand,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*3/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.RecordTag=uicontrol('Style', 'text', ...
    'Parent', gui.handles.panel(3), ...
    'BackgroundColor', BackgroundColor,...
    'Units', 'Pixels', 'Position', [FigureWidth/10 FigureHeight*1/10 FigureWidth*8/10 FigureHeight/10],...
    'FontUnits','pixels','FontSize', EBFont);

%% Forth Panel

gui.handles.panel(4)= uipanel('Units', 'pixels', ...
    'BorderWidth', 0, ...
    'Units', 'Pixels', 'Position', [0 0 FigureWidth FigureHeight], ...
    'Visible','off', ...
    'BackgroundColor', BackgroundColor);

text={'--Real Time--';...
    '';...
    'Choose one of the options below:'};

uicontrol('Style','text',...
    'Parent', gui.handles.panel(4),...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight/2 FigureWidth/2 FigureHeight*2/5],...
    'BackgroundColor',BackgroundColor,...
    'string', text, ...
    'HorizontalAlignment','center',...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(9)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(4), ...
    'String', 'Test on Command Window', ...
    'Callback', @TestRealTime,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*5/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(10)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(4), ...
    'String', 'Maze', ...
    'Callback', @Maze,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*3/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(11)=uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(4), ...
    'String', 'Back', ...
    'Callback', @Back2,...
    'Units', 'Pixels', 'Position', [FigureWidth/4 FigureHeight*1/10 FigureWidth/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

%% Fith Panel(Maze)
gui.handles.panel(5)= uipanel('Units', 'pixels', ...
    'BorderWidth', 0, ...
    'Units', 'Pixels', 'Position', [0 0 FigureWidth FigureHeight], ...
    'Visible','off', ...
    'BackgroundColor', [0 0 0]); % Black

gui.handles.MazeBox = axes('Parent',gui.handles.panel(5),...
    'Units', 'Pixels', 'Position',[(FigureWidth-FigureHeight*.9*5/4) FigureHeight/20 FigureHeight*.9*5/4 FigureHeight*.9]);

gui.handles.button(12) = uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(5), ...
    'String', 'Back', ...
    'Callback', @Back3,...
    'Units', 'Pixels', 'Position', [(FigureWidth-FigureHeight*.9*5/4)/4 FigureHeight*1/10 (FigureWidth-FigureHeight*.9*5/4)/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(13) = uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(5), ...
    'String', 'Start', ...
    'Callback', @RunGame,...
    'Units', 'Pixels', 'Position', [(FigureWidth-FigureHeight*.9*5/4)/4 FigureHeight*3/10 (FigureWidth-FigureHeight*.9*5/4)/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

gui.handles.button(14) = uicontrol('Style', 'pushbutton', ...
    'Parent', gui.handles.panel(5), ...
    'String', 'Stop', ...
    'Callback', @StopGame,...
    'Units', 'Pixels', 'Position', [(FigureWidth-FigureHeight*.9*5/4)/4 FigureHeight*3/10 (FigureWidth-FigureHeight*.9*5/4)/2 FigureHeight/10],...
    'FontUnits','pixels','FontSize', BFont);

imshow(Graphic,'Parent',gui.handles.MazeBox);
pause(0.001);


%% Callback function
    function About(~,~,~)
        text = {'ECE446 Fall 2014 Final Project';...
            'Word Recognition';...
            '';...
            'Students:';...
            'Octavia Deaconescu';...
            'Ruben Larsson';...
            'Daniel Lee';...
            'Luke Liu';...
            'Alexandre Ribeiro'};
        
        FigureWidth=ScreenX*msgScale;
        FigureHeight=ScreenY*msgScale;
        FigurePositionX=(ScreenX-FigureWidth)/2;
        FigurePositionY=(ScreenY-FigureHeight)/2;
        
        h = figure(...
            'Units','pixels',...
            'Units', 'Pixels', 'Position',[FigurePositionX, FigurePositionY, FigureWidth, FigureHeight],...
            'NumberTitle','off',...
            'Toolbar','none',...
            'Resize','off',...
            'Menubar','none',...
            'DockControls','off',...
            'Color',BackgroundColor ,...
            'Name','About');
        
        uicontrol('Style','text',...
            'Parent', h,...
            'Units', 'Pixels', 'Position', [0 0 FigureWidth FigureHeight],...
            'BackgroundColor',BackgroundColor,...
            'string', text , ...
            'HorizontalAlignment','center',...
            'FontUnits','pixels','FontSize', BFont);
    end

    function Restart(~,~,~)
        pause(0.1);
        close all
        clear all
        WordRecognition;
    end

    function CalibrateZero(~,~,~)
        % Gui Stuff
        text = {'';...
            '';...
            'Please be silent';...
            '';...
            'This window will disapper when the calibration is finished'};
        
        FigureWidth=ScreenX*msgScale;
        FigureHeight=ScreenY*msgScale;
        FigurePositionX=(ScreenX-FigureWidth)/2;
        FigurePositionY=(ScreenY-FigureHeight)/2;
        
        h = figure(...
            'Units','pixels',...
            'Units', 'Pixels', 'Position',[FigurePositionX, FigurePositionY, FigureWidth, FigureHeight],...
            'NumberTitle','off',...
            'Toolbar','none',...
            'Resize','off',...
            'Menubar','none',...
            'DockControls','off',...
            'Color',BackgroundColor ,...
            'Name','Calibration');
        
        uicontrol('Style','text',...
            'Parent', h,...
            'Units', 'Pixels', 'Position', [0 0 FigureWidth FigureHeight],...
            'BackgroundColor',BackgroundColor,...
            'string', text , ...
            'HorizontalAlignment','center',...
            'FontUnits','pixels','FontSize', BFont);
        % Calibrating
        set(gui.handles.button,'Enable','off');
        y = RecordAudio(ZeroCalibrationTime);
        
        BufferedSignal=buffer(y,BufferBlockLength,0,'nodelay');
        WindowedSignal=diag(HamW)*BufferedSignal;
        Energy=sum(WindowedSignal.^2,1);
        
        ZeroEnergy = mean(Energy) + 2*TCoef*std(Energy);
        
        waitfor(msgbox(['Calibrated to ' num2str(ZeroEnergy) ' zero energy.'],'Calibrated'));
        
        if ZeroEnergy > ZeroEnergyMax
            warndlg('Place too noise. Consider going to a more quiet place and recalibrate','Warning!');
        end
        
        set(gui.handles.button,'Enable','on');
        
        if ishandle(h)
            close(h)
        end
        
    end

    function ChooseLibrary(~,~,~)
        set(gui.handles.panel(1),'Visible','off');
        set(gui.handles.panel(2),'Visible','on');
        set(gui.handles.RecordTag,'Visible','off');
    end

    function LoadLibrary(~,~,~)
        persistent StartDir
        if isempty(StartDir)
            StartDir=cd;
        end
        set(gui.handles.button,'Enable','off');
        [FileName, FileDir] = uigetfile({'*.mat','Supported files(.mat)'},'Select Library file', StartDir);
        if FileName ~= 0
            StartDir = FileDir;
            load([FileDir FileName],'Library');
            database = Library;
            ZeroEnergy = database.ZeroEnergy;
            msgbox('Sucessfully loaded','Load');
            set(gui.handles.panel(2),'Visible','off');
            set(gui.handles.panel(1),'Visible','on');
        end
        set(gui.handles.button,'Enable','on');
    end

    function CreateNewLibrary(~,~,~)
        set(gui.handles.panel(2),'Visible','off');
        set(gui.handles.panel(3),'Visible','on');
        set(gui.handles.RecordTag,'Visible','off');
        waitfor(warndlg('Choose the name for your library but keep in mind it will overwrite any .mat file on the current directory with the same name.','Warning!'));
        TempLibrary.name={};
        TempLibrary.name=inputdlg('Enter the library name','Title');
        if isempty(TempLibrary.name)
            set(gui.handles.panel(2),'Visible','on');
            set(gui.handles.panel(3),'Visible','off');
        end
    end

    function RecordCommand(~,~,~)
        set(gui.handles.button,'Enable','off');
        set(gui.handles.RecordTag,'string','Recording...','Visible','on');
        pause(0.1);
        
        TempLibrary.audio{CommandIndex} = RecordSoundEnergy;
        TempAudio = TempLibrary.audio{CommandIndex};
        soundsc(TempAudio,Fs);
        
        if length(TempAudio) < MelBlockLength
            warndlg('Word not found','Warning!');
        else
            TempLibrary.tempmfcc{CommandIndex} = mfcc(TempAudio);
            CommandFlag = true;
        end
        
        set(gui.handles.button,'Enable','on');
        set(gui.handles.RecordTag,'Visible','off');
    end

    function NextCommand(~,~,~)
        if CommandFlag
            CommandFlag = false;
            CommandIndex = CommandIndex +1;
            if CommandIndex == 2*NumberOfCommands
                set(gui.handles.button(8),'String','Finish');
            end
            if CommandIndex ~= 2*NumberOfCommands + 1
                if mod(CommandIndex,2) == 0
                    text=['Press "Record", wait a couple of seconds for the recorder to initialize and say "' CommandList{CommandIndex/2} '" again.'] ;
                else
                    text=['Press "Record", wait a couple of seconds for the recorder to initialize and say "' CommandList{ceil(CommandIndex/2)} '".'] ;
                end
                set(gui.handles.RecordText,'string',text);
            else
                set(gui.handles.button(8),'String','Next Command');
                set(gui.handles.panel(3),'Visible','off');
                set(gui.handles.panel(1),'Visible','on');
                TempLibrary.Score=zeros(NumberOfCommands);
                for i=1:2*NumberOfCommands
                    for j=i:2*NumberOfCommands
                        [Dist,NormFactor]=dtwk(TempLibrary.tempmfcc{i},TempLibrary.tempmfcc{j});
                        TempLibrary.Score(i,j)=Dist/NormFactor;
                        TempLibrary.Score(j,i)=Dist/NormFactor;
                    end
                end
                match=zeros(1,2*NumberOfCommands);
                mismatch=zeros(1,2*NumberOfCommands);
                for i=1:2*NumberOfCommands
                    if mod(i,2) ~= 0
                        match(i)=TempLibrary.Score(i,i+1);
                        mismatch(i)=min(TempLibrary.Score(i,[1:i-1 i+2:end]));
                    else
                        match(i)=TempLibrary.Score(i,i-1);
                        mismatch(i)=min(TempLibrary.Score(i,[1:i-2 i+1:end]));
                    end
                end
                TempLibrary.Threshold=min(mismatch);
                TempLibrary.name = TempLibrary.name{1};
                TempLibrary.mfcc=TempLibrary.tempmfcc(1:2:(2*NumberOfCommands-1));
                TempLibrary.ZeroEnergy = ZeroEnergy;
                TempLibrary.WordEnergy = WordEnergy;
                database = TempLibrary;
                Library = TempLibrary; %#ok<NASGU>
                save(TempLibrary.name,'Library');
                CommandIndex = 1;
                text=['Press "Record", wait a couple of seconds for the recorder to initialize and say "' CommandList{ceil(CommandIndex/2)} '".'] ;
                set(gui.handles.RecordText,'string',text);
                if max(match)>min(mismatch)
                    warndlg('Your words showed a weak correlation. Consider creating a new library.','Warning!')
                else
                    msgbox('Your words showed a strong correlation!','Library')
                end
            end
        else
            warndlg('Record the command before moving on.','Warning!')
        end
    end

    function Back(~,~,~)
        set(gui.handles.panel(2),'Visible','off');
        set(gui.handles.panel(1),'Visible','on');
    end

    function Back2(~,~,~)
        set(gui.handles.panel(4),'Visible','off');
        set(gui.handles.panel(1),'Visible','on');
    end

    function Back3(~,~,~)
        GameRunning = false;
        set(gui.handles.panel(5),'Visible','off');
        set(gui.handles.panel(1),'Visible','on');
    end

    function RealTimeTab(~,~,~)
        if isempty(database)
            warndlg('Load or create a library before moving on!','Warning!');
        else
            set(gui.handles.panel(1),'Visible','off');
            set(gui.handles.panel(4),'Visible','on');
        end
    end

    function TestRealTime(~,~,~)
        Counter = 1;
        if RealTimeRunFlag
            set(gui.handles.button(9),'string', 'Test on Command Window');
            RealTimeRunFlag = false;
            pause(0.001);
        else
            set(gui.handles.button(9),'string', 'Stop Test');
            RealTimeRunFlag = true;
            waitfor(msgbox(['Go to command window to see the ouput. The code will run for ' num2str(RealTimeRun) ' seconds.','Real Time']))
            pause(1);
            AI= dsp.AudioRecorder('SampleRate',Fs,'SamplesPerFrame',BufferBlockLength,'NumChannels',1,'QueueDuration',QueueDuration);
            disp(['Your threshold is ' num2str(database.Threshold)]);
            tic
            while toc < RealTimeRun && RealTimeRunFlag
                Frame=step(AI);
                energy=BlockEnergy(Frame);
                if energy >= ZeroEnergy
                    BufferVector((BufferIndex-1)*BufferBlockLength+1:BufferIndex*BufferBlockLength)=Frame;
                    BufferIndex=BufferIndex+1;
                    if energy >= WordEnergy
                        WordFlag=true;
                    end
                else
                    if WordFlag==true
                        WordFlag=false;
                        Word=BufferVector(1:BufferIndex*BufferBlockLength);
                        Mel=mfcc(Word);
                        for i=1:NumberOfCommands
                            [TempScore, NormFactor]=dtwk(Mel,database.mfcc{i});
                            RealTimeScore(i)=TempScore/NormFactor;
                        end
                        [mScore, command]=min(RealTimeScore);
                        if mScore <= database.Threshold
                            disp(CommandList{command});
                        else
                            disp(['No Match. Your score was ' num2str(mScore)]);
                        end
                    end
                    BufferVector=zeros(1,BigBufferSize);
                    BufferIndex=1;
                end
                if toc > Counter*(UpdateRate/10)
                    Counter=Counter+1;
                    pause(0.001);
                end
            end
            release(AI);
            delete(AI);
            set(gui.handles.button(9),'string', 'Test on Command Window');
        end
        
    end

    function CloseFigure(~,~,~)
        RealTimeRunFlag = false;
        GameRunning = false;
        clearvars -global;
        closereq;
    end

    function Maze(~,~,~)
        
        set(gui.handles.panel(4),'Visible','off');
        set(gui.handles.panel(5),'Visible','on');
        set(gui.handles.button(13),'Visible','on');
        set(gui.handles.button(14),'Visible','off');
        pause(0.001);
        
    end

    function RunGame(~,~,~)
        set(gui.handles.button(13),'Visible','off');
        set(gui.handles.button(14),'Visible','on');
        % Car starting position
        CarCurrentPosition=[37,1]; % Position [y,x]
        CarOldPosition=[37,1];     % Position [y,x]
        Direction='pause';
        %Initializing Counters
        TempGraphic= AddCarToGraphic;
        imshow(TempGraphic,'Parent',gui.handles.MazeBox);
        pause(0.1);
        GameRunning = true;
        SpeedCounter = 1;
        UpdateCounter = 1;
        AI= dsp.AudioRecorder('SampleRate',Fs,'SamplesPerFrame',BufferBlockLength,'NumChannels',1,'QueueDuration',QueueDuration);
        tic
        while GameRunning
            % Audio processing
            Frame=step(AI);
            energy=BlockEnergy(Frame);
            if energy >= ZeroEnergy
                BufferVector((BufferIndex-1)*BufferBlockLength+1:BufferIndex*BufferBlockLength)=Frame;
                BufferIndex=BufferIndex+1;
                if energy >= WordEnergy
                    WordFlag=true;
                end
            else
                if WordFlag==true
                    WordFlag=false;
                    Word=BufferVector(1:BufferIndex*BufferBlockLength);
                    Mel=mfcc(Word);
                    for i=1:NumberOfCommands
                        [TempScore, NormFactor]=dtwk(Mel,database.mfcc{i});
                        RealTimeScore(i)=TempScore/NormFactor;
                    end
                    [mScore, command]=min(RealTimeScore);
                    if mScore <= database.Threshold
                        switch command
                            case 1
                                Direction ='up';
                            case 2
                                Direction = 'down';
                            case 3
                                Direction = 'left';
                            case 4
                                Direction = 'right';
                            case 5
                                Direction = 'pause';
                        end
                        disp(CommandList{command});
                    else
                        disp(['No Match. Your score was ' num2str(mScore)]);
                    end
                end
                BufferVector=zeros(1,BigBufferSize);
                BufferIndex=1;
            end
            % Maze
            %Update Position
            if toc >= SpeedCounter*(1/CarSpeed)
                SpeedCounter=SpeedCounter + 1;
                switch Direction
                    case 'up'
                        CarStopPosition = CarCurrentPosition;
                        CarCurrentPosition=CarCurrentPosition+[-1,0]; % Position [y,x]
                    case 'down'
                        CarStopPosition = CarCurrentPosition;
                        CarCurrentPosition=CarCurrentPosition+[1,0]; % Position [y,x]
                    case 'left'
                        CarStopPosition = CarCurrentPosition;
                        CarCurrentPosition=CarCurrentPosition+[0,-1]; % Position [y,x]
                    case 'right'
                        CarStopPosition = CarCurrentPosition;
                        CarCurrentPosition=CarCurrentPosition+[0,1]; % Position [y,x]
                    case 'pause'
                        CarStopPosition = CarCurrentPosition;
                        CarCurrentPosition=CarCurrentPosition+[0,0]; % Position [y,x]
                end
                
                %Check if finish. If not check if it hit a wall
                %Finish
                if CarCurrentPosition(1) >= FinishRows(1) &&...
                        CarCurrentPosition(1) <= FinishRows(2) &&...
                        CarCurrentPosition(2) == FinishColumn
                    StopGame;
                    disp('You Finish');
                    msgbox('Congratulations! You got to the end of the maze.','Congratulations!');
                elseif  CarCurrentPosition(1)<=0 ||...
                        CarCurrentPosition(1) > MazeFieldSize(1) ||...
                        CarCurrentPosition(2) <= 0 ||...
                        CarCurrentPosition(2) > MazeFieldSize(2)
                    CarCurrentPosition = CarStopPosition;
                    Direction='stop';
                    disp('You hit a wall');
                    disp(num2str(CarCurrentPosition));
                    % Add messages here
                elseif Field(CarCurrentPosition(1),CarCurrentPosition(2))~=0
                    CarCurrentPosition = CarStopPosition;
                    Direction='stop';
                    disp('You hit a wall');
                    disp(num2str(CarCurrentPosition));
                    % Add messages here
                end
                
            end
            
            if toc >= UpdateCounter*(1/UpdateRate)
                UpdateCounter=UpdateCounter+1;
                TempGraphic = AddCarToGraphic;
                imshow(TempGraphic,'Parent',gui.handles.MazeBox);
                pause(0.001);
                CarOldPosition = CarCurrentPosition;
            end
            
        end
        
        
    end

    function StopGame(~,~,~)
        GameRunning = false;
        set(gui.handles.button(13),'Visible','on');
        set(gui.handles.button(14),'Visible','off');
    end
%% Auxiliar functions
    function Car = CreateCar
        CarColorChoices=[0,0,1;...  % Blue
            0,1,0;... % Green
            0,1,1;... % Cyan
            1,0,0;... % Red
            1,0,1;... % Magenta
            1,1,0];   % Yellow
        
        CarColor=CarColorChoices(randi([1, size(CarColorChoices,2)]),:);
        
        Car=uint8(zeros(SquareSize,SquareSize,3));
        
        for i=1:SquareSize
            for j=1:SquareSize
                for ColorID =1:3
                    Car(i,j,ColorID) = 255*CarColor(ColorID);
                end
            end
        end
    end

    function Field = CreateMazeField
        Field=uint8(zeros(MazeFieldSize));
        % Create the template
        %Draw all the vertical maze lines -> (0,0) is the top left corner
        for rows=1:34
            Field(rows,1)=255;
        end
        for rows=10:20
            Field(rows,17)=255;
        end
        for rows=16:20
            Field(rows,25)=255;
        end
        for rows=25:30
            Field(rows,25)=255;
        end
        for rows=20:25
            Field(rows,33)=255;
        end
        for rows=30:35
            Field(rows,41)=255;
        end
        for rows=10:20
            Field(rows,41)=255;
        end
        for rows=1:14
            Field(rows,49)=255;
            Field(rows,50)=255;
        end
        %The end point of the maze
        for rows=21:40
            Field(rows,50)=255;
        end
        %Draw all the horizontal lines to complete the maze
        for cols=1:50  %Don't draw the top horizontal line (row==1)
            Field(40,cols)=255;
        end
        for cols=10:50
            Field(5,cols)=255;
        end
        for cols=10:41
            Field(10,cols)=255;
        end
        for cols=1:9
            Field(15,cols)=255;
        end
        for cols=34:41
            Field(15,cols)=255;
        end
        for cols=10:33
            Field(20,cols)=255;
        end
        for cols=41:50
            Field(20,cols)=255;
        end
        for cols=1:25
            Field(25,cols)=255;
        end
        for cols=33:40
            Field(25,cols)=255;
        end
        for cols=1:16
            Field(30,cols)=255;
        end
        for cols=25:41
            Field(30,cols)=255;
        end
        for cols=10:41
            Field(35,cols)=255;
        end
    end

    function Graphic = CreateGraphic
        Graphic=uint8(zeros(MazeFieldSize(1)*SquareSize,MazeFieldSize(2)*SquareSize,3));
        for row=1:MazeFieldSize(1)
            for col=1:MazeFieldSize(2)
                if Field(row,col)==0
                    %100 is the shade of grey of the background
                    Graphic(((row-1)*SquareSize)+1:(row*SquareSize),...
                        ((col-1)*SquareSize)+1:(col*SquareSize),:)=100;
                elseif Field(row,col)==255
                    %0 is black for the maze walls
                    Graphic(((row-1)*SquareSize)+1:(row*SquareSize),...
                        ((col-1)*SquareSize)+1:(col*SquareSize),:)=0;
                end
            end
        end
    end

    function TempGraphic = AddCarToGraphic
        TempGraphic = Graphic;
        % Remove car from graphic
        row=CarOldPosition(1);
        col=CarOldPosition(2);
        TempGraphic(((row-1)*SquareSize)+1:(row*SquareSize),...
            ((col-1)*SquareSize)+1:(col*SquareSize),:)=100;
        
        % Add car to graphic
        row=CarCurrentPosition(1);
        col=CarCurrentPosition(2);
        TempGraphic(((row-1)*SquareSize)+1:(row*SquareSize),...
            ((col-1)*SquareSize)+1:(col*SquareSize),:)=Car;
    end

    function Word = RecordSoundEnergy
        BufferVector=zeros(1,BigBufferSize);
        BufferIndex=1;
        Flag=false;
        AI= dsp.AudioRecorder('SampleRate',Fs,'SamplesPerFrame',BufferBlockLength,'NumChannels',1,'QueueDuration',QueueDuration);
        while ~Flag
            Frame=step(AI);
            energy=BlockEnergy(Frame);
            if energy >= ZeroEnergy
                BufferVector((BufferIndex-1)*BufferBlockLength+1:BufferIndex*BufferBlockLength)=Frame;
                BufferIndex=BufferIndex+1;
                if energy >= WordEnergy
                    WordFlag=true;
                end
            else
                if WordFlag==true
                    WordFlag=false;
                    Word=BufferVector(1:BufferIndex*BufferBlockLength);
                    Flag=true;
                end
                BufferVector=zeros(1,BigBufferSize);
                BufferIndex=1;
            end
        end
        release(AI);
        delete(AI);
    end

    function c = mfcc(y)
        
        % Creating the periodogram of the input
        SigFramed=buffer(y,MelBlockLength,MelBufferOverlap,'nodelay');
        sigWindowed = diag(HamWMel) * SigFramed;
        Ski=fft(sigWindowed);
        Pki=1/MelBlockLength*abs(Ski).^2;
        Periodogram=Pki(1:(MelBlockLength/2+1),:);
        
        % Applying the Mel filter bank
        columns=size(Periodogram,2);
        c=zeros(NFilter,columns);
        for i=1:columns
            L=diag(Periodogram(:,i))*MelBank; % Apply the filter bank to the signal
            energy=sum(L,1);    % Sum the values of each bank
            % Get the coefficients
            x=log(energy);
            c(:,i)=idct(x);
        end
        
        c=c(Coef,:); % Get the first 13 coefficients
    end

    function Signal = RecordAudio(Time)
        Recorder = audiorecorder(Fs,16,1,AudioInputDevice);
        recordblocking(Recorder,Time);
        Signal=getaudiodata(Recorder);
    end

    function m = Hz2Mel(f)
        m=1125*log(1+f/700);
    end

    function f =Mel2Hz(m)
        f=700*(10.^(m/2595)-1);
    end

    function H = MelFilterBank
        % Defining the lower and upper bound of the filter bank in Mel
        MelHigh=Hz2Mel(MelUpperFreq);
        MelLow=Hz2Mel(MelLowerFreq);
        % Getting equally spaced frequencies in Mel Scale
        FilterBankMel=linspace(MelLow,MelHigh,NFilter+2);
        % Convert back to Hz
        FilterBankHz=Mel2Hz(FilterBankMel);
        FilterIndices=round((MelFilterSize+1)*FilterBankHz/Fs*2);
        H=zeros(MelFilterSize, NFilter);
        
        % Defining the triangular filters
        for j=1:NFilter
            for i=FilterIndices(j):FilterIndices(j+2)
                if i<FilterIndices(j+1)
                    H(i,j)=(i-FilterIndices(j))/(FilterIndices(j+1)-FilterIndices(j));
                else
                    H(i,j)=(FilterIndices(j+2)-i)/(FilterIndices(j+2)-FilterIndices(j+1));
                end
            end
        end
    end

    function E = BlockEnergy(y)
        win=y.*HamW;
        E=sum(win.^2);
    end

    function [Dist, NormFactor]=dtwk(t,r)
        %Dynamic Time Warping Algorithm
        %Dist is unnormalized distance between t and r
        %The orinal code by T. Felty [10]
        %Modify by Parinya Sanguansat
        %Modified by Alex
        
        
        [row,N]=size(t);  %#ok<ASGLU>
        [rows,M]=size(r);
        d = 0;
        NormN=N;
        NormM=M;
        
        for i=1:rows
            tt = t(i,:);
            rr = r(i,:);
            tt = (tt-mean(tt))/std(tt);
            rr = (rr-mean(rr))/std(rr);
            d = d + (repmat(tt(:),1,M) - repmat(rr(:)',N,1)).^2;
        end
        
        D=zeros(size(d));
        D(1,1)=d(1,1);
        
        for n=2:N
            D(n,1)=d(n,1)+D(n-1,1);
        end
        
        for m=2:M
            D(1,m)=d(1,m)+D(1,m-1);
        end
        
        for n=2:N
            for m=2:M
                [Value, Index]=min([D(n-1,m), D(n-1,m-1),D(n,m-1)]);
                D(n,m)=d(n,m)+Value;
                switch Index
                    case 1
                        NormM=NormM+1;
                    case 3
                        NormN=NormN+1;
                end
            end
        end
        Dist=D(N,M);
        switch NormFactorType
            case 1
                NormFactor=1;
            case 2
                NormFactor = N +M;
            case 3
                NormFactor = max(NormM,NormN);
        end
    end

end