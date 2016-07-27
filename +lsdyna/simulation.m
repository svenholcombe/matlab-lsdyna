classdef simulation < handle
    %lsdyna.simulation Run one or more LS-Dyna simulations from MATLAB
    %
    %
    % Basic usage (run one simulation):
    %  S = lsdyna.simulation('C:\FolderToSim\mainFile.k')
    %  S.run
    %
    %
    % Multiple simulations (in series):
    %  baseFolder = 'C:\FolderToSims';
    %  for i = 1:10
    %     simFolder = fullfile(baseFolder,sprintf('sim%d',i));
    %     S(i) = lsdyna.simulation(fullfile(simFolder,'mainFile.k'));
    %  end
    %  S.run % Each simulation will be run, one after the other
    %
    %
    % Multiple simulations (in parallel):
    %  baseFolder = 'C:\FolderToSims';
    %  for i = 1:10
    %     simFolder = fullfile(baseFolder,sprintf('sim%d',i));
    %     S(i) = lsdyna.simulation(fullfile(simFolder,'mainFile.k'));
    %     S(i).cmdBlocking = false;
    %  end
    %  % Run simulations in parallel using 4 threads. The first 4
    %  % simulations will start in a new command window, and when each is
    %  % complete, it will fire the next simulation to run in the available
    %  % thread.
    %  S.run('threads',4)
    %
    % Note:
    %  Listeners can be added to the following events for a simulation in
    %  order to automatically fire cleanup/read functions:
    %     SimProcComplete	Event fired when the dyna.exe command finishes 
    %     SimProcStarting	Event fired when dyna.exe command is starting 
    %     SimTermination	Event fired when termination status is known/read 
    
    
    properties (Transient)
        folder % Input folder for simulation
        inputFile % Main .k or .key file to be executed
    end
    properties (Hidden)
        cmdProcessId % Windows processId for the command line window running dyna.exe
        cmdNonBlockingListener % Storage for listener object that runs when running dyna asynchronously
        cmdStartedTime % Storage for the timestamp when executable called
        cmdLastCheckedTime % Storage for the timestamp when executable last checked for completion
    end
    properties
        cmdBlocking = true; % Set to false to run dyna as separate asynchronous process
        cmdPollingPeriod = 2; % Seconds between checks for Dyna .exe completion
        cmdTimeoutDuration = minutes(inf);
        terminationStatus = 'Unknown' % Error / Normal / Unknown / Timeout
        terminationTime % Timestamp of simulation completion
        messagContents % Contents of output "messag" file
    end
    
    properties (Constant, Hidden)
        dynaExe = 'C:\LSDYNA\program\ls-dyna_smp_s_R610_winx64_ifort101.exe'
    end
    properties (Dependent, Hidden)
        asciiFullfile
        storageMatFullfile
    end
    properties
        PreSimCallback % Callback called before simulation is run
    end
    events
        SimProcStarting % Event fired when dyna.exe command is starting
        SimProcComplete % Event fired when the dyna.exe command finishes
        SimTermination % Event fired when termination status is known/read
    end
    methods %% Utility methods
        function runInThreads(this,varargin)
            IP = inputParser;
            IP.addParameter('threads', 4)
            IP.parse(varargin{:})
            opts = IP.Results;
            
            lstnrCell = cell(1,opts.threads);
            
            nSims = numel(this);
            currSimNo = 0;
            
            % Start N threads
            for i = 1:opts.threads
                runNextSim()
            end
            
            function runNextSim()
                currSimNo = currSimNo + 1;
                if currSimNo > nSims
                    return;
                end
                nextCellNo = find(cellfun(@isempty, lstnrCell),1);
                runSimNoInCellNo(currSimNo,nextCellNo)
            end
            function runSimNoInCellNo(simNo,slotNo)
                % Listen for the termination of this sim, and go!
                lstnrCell{slotNo} = addlistener(...
                    this(simNo),'SimTermination',@(~,~)cleanupLstnrNo(slotNo,simNo));
                fprintf('Sim %d of %d [slot #%d]: Starting ...\n', simNo, nSims, slotNo)
                this(simNo).run
            end
            function cleanupLstnrNo(lstnrNo,simNo)
                % Delete the old listener and clear out a spot in the queue
                fprintf('Sim %d of %d [slot #%d]: Ended.\n', simNo, nSims, lstnrNo)
                delete(lstnrCell{lstnrNo})
                lstnrCell{lstnrNo} = [];
                runNextSim()
            end
            
        end
        function run(this,varargin)
            % sim.run
            % sims.run('threads',4)
            
            %% Handle multiple sims
            if numel(this)>1 && any(~[this.cmdBlocking])
                this.runInThreads(varargin{:})
                return;
            end
            
            %% Call for any pre-simulation code to be run
            if ~isempty(this.PreSimCallback)
                this.PreSimCallback();
            end
            
            %%
            baseExecStr = sprintf('cd /d "%s" & %s I=%s O=d3hsp',...
                this.folder, this.dynaExe, this.inputFile);
            this.systemCheck
            if this.cmdBlocking
                execStr = baseExecStr;
            else
                % We want to spawn a new non-blocking process
                execStr = [baseExecStr ' & '];
                % But we need to keep track of this new process. First,
                % gather any old processes that may have been spawned
                thispid = feature('getpid');
                wmicOut = 'commandline,processid';
                wmicStr = sprintf(['wmic process where ' ...
                    '(name="%s" and parentprocessid="%d" ' ...
                    'and commandline like "%%%s%%" and commandline like "%%%s%%") get %s'],...
                    'cmd.exe', thispid, strrep(this.folder,'\','\\'),...
                    strrep(this.inputFile,'\','\\'), wmicOut);
                [~,pList] = system(wmicStr);
                wmicReturns = strsplit(strtrim(pList),'\n')';
                % ProcessIds of pre-existing cmd windows
                oldChildProcStrs = regexp(wmicReturns(2:end),'\d+$','match','once');
            end
            
            % Run the actual DYNA simulation!
            notify(this,'SimProcStarting')
            this.cmdStartedTime = datetime;
            status = system(execStr);
            if status>1
                warning('Execution of LS-Dyna command failed!')
            end
            
            % Handle a running or finished command line
            if this.cmdBlocking
                % The cmd.exe process has complete!
                notify(this,'SimProcComplete');
            else
                % We can try to identify the cmd.exe process we just made
                [~,pList] = system(wmicStr);
                wmicReturns = strsplit(strtrim(pList),'\n')';
                % ProcessIds of pre-existing cmd windows
                currChildProcStrs = regexp(wmicReturns(2:end),'\d+$','match','once');
                newChildProcStrs = setdiff(currChildProcStrs, oldChildProcStrs);
                
                if isempty(newChildProcStrs)
                    warning('Could not detect spawned LS-Dyna executing process')
                elseif length(newChildProcStrs)==1
                    % Found it!
                    this.cmdProcessId = newChildProcStrs{1};
                    fprintf('LS-Dyna called within cmd.exe (procid %s) spawned by MATLAB (procid %d)\n', this.cmdProcessId, thispid)
                    fprintf('Simulation termination will be checked at %gs intervals.\n', this.cmdPollingPeriod)
                    % Listen to a sim completion event to close cmd window
                    delete(this.cmdNonBlockingListener)
                    this.cmdNonBlockingListener = addlistener(this,'SimProcComplete',...
                        @(src,evnt)system(sprintf(...
                        'wmic process where processid="%s" call terminate',...
                        this.cmdProcessId)));
                    % Use a timer to poll for the dyna exe process status,
                    % and fire an event when that timer is closed
                    t = timer;
                    t.TimerFcn = @(timerObj,~)this.pollSystemExe(timerObj);
                    t.StopFcn = @(obj,evnt)notify(this,'SimProcComplete');
                    t.Period = this.cmdPollingPeriod;
                    t.ExecutionMode = 'fixedSpacing';
                    start(t)
                    
                else
                    warning('Multiple new LS-Dyna executing processes detected!')
                end
            end
        end
        
        function fetchSimulationStatus(this, fireTerminationEvent)
            % Hunt through the messag file for termination status
            msgFileStr = fullfile(this.folder,'messag');
            if exist(msgFileStr,'file')
                this.messagContents = fileread(msgFileStr);
                [~,~,~,~,termParts] = regexp(this.messagContents,'^ ([\w ]*)  t e r m i n a t i o n \s+(.{17})','lineanchors','match','once');
                if ~isempty(termParts)
                    this.terminationStatus = strrep(termParts{1},' ','');
                    this.terminationTime = datetime(termParts{2},'InputFormat','MM/dd/uuuu HH:mm:ss');
                else
                    warning('No termination information found in %s',msgFileStr)
                end
            else
                warning('No messag file was found in %s',this.folder)
            end
            if nargin>1 && fireTerminationEvent
                notify(this,'SimTermination')
            end
        end
        
        function pollSystemExe(this,timerObj)
            % Utility to check unblocked dyna process for completion
            [~,wmicOutput] = system(sprintf(...
                'wmic process where (parentprocessid="%s" and executablepath="%s") get commandline,processid',...
                this.cmdProcessId, strrep(this.dynaExe,'\','\\')));
            wmicOutputs = strsplit(strtrim(wmicOutput),'\n')';
            if numel(wmicOutputs)==2
                % Do nothing - simulation still running
                this.cmdLastCheckedTime = datetime;
                % Check if we should be timing out
                if isfinite(this.cmdTimeoutDuration)
                    durationRunning = this.cmdLastCheckedTime - this.cmdStartedTime;
                    if durationRunning > this.cmdTimeoutDuration
                        warning('%s: Timeout (%s) reached - killing simulation...: %s\n',datestr(now),char(this.cmdTimeoutDuration),this.folder)
                        stop(timerObj)
                        delete(timerObj)
                        notify(this,'SimProcComplete')
                    end
                end
            elseif numel(wmicOutputs) < 2
                % There is no child dyna process of our registered cmd.exe
                % process. Presume it has now finished.
                fprintf('%s: Asynchronous simulation complete: %s\n',datestr(now),this.folder)
                if nargin>1
                    stop(timerObj)
                    delete(timerObj)
                end
            else
                warning('Unexpected number of child processes found')
            end
        end
        function systemCheck(this)
            % Check that we've got a dyna executable to run
            if ~exist(this.dynaExe,'file')
                error('LS-Dyna executable %s not found',this.dynaExe)
            end
            
            % Holy crap this one was tough to track down. There's a
            % potentially troublesome way that MATLAB sets up environment
            % variables when it opens a new system cmd window. Cheers to
            % James Kennedy from the Dyna User's Group for helping to
            % identify this issue.
            oldEnv = getenv('KMP_STACKSIZE');
            if ~isempty(regexp(oldEnv,'[^0-9]','once'))
                newEnv = strrep(strrep(oldEnv,'k','000'),'m','000000');
                setenv('KMP_STACKSIZE',newEnv)
                warning('Incompatible KMP_STACKSIZE environment variable (%s) changed to: %s',...
                    oldEnv, newEnv)
            end
        end
    end
    methods
        % Constructor
        function this = simulation(inputFolder,varargin)
            % Accept a directory (or file) to look for
            if exist(inputFolder,'dir')
                this.folder = inputFolder;
                % Attempt to find the main k or key file
                kFiles = dir(fullfile(this.folder,'*.k*'));
                if numel(kFiles)==1
                    this.inputFile = kFiles.name;
                end
            elseif exist(inputFolder,'file')
                [this.folder,b,c] = fileparts(inputFolder);
                this.inputFile = [b c];
            else
                warning('Input file/folder (%s) does not exist!', inputFolder)
            end
            
            % Specify basic Norm/Err status when a sim process completes
            addlistener(this,'SimProcComplete',@(src,~)src.fetchSimulationStatus(true));
            addlistener(this,'SimTermination',@(src,~)...
                fprintf('Simulation complete with %s termination (%s): %s\n',...
                src.terminationStatus,datestr(src.terminationTime),src.folder));
        end
    end
end