classdef elout < lsdyna.read.DATABASE_FILE
    %ELOUT Read element stress/strain output LS-DYNA ascii file
    %   elout = lsdyna.read.elout(folder)
    
    properties
        file = 'elout'
        SHELL_ELEM_INFO
        SHELL_DATA
        BEAM_ELEM_INFO
        BEAM_DATA
    end
    
    methods
        function this = elout(varargin)
            this = this@lsdyna.read.DATABASE_FILE(varargin{:});
        end
        function addDerivedDataChannels(this)
            
            if ~isempty(this.SHELL_DATA) && ~any(strcmp('stress_vm',this.SHELL_DATA.Properties.VariableNames))
                xx = this.SHELL_DATA.sig_xx;
                yy = this.SHELL_DATA.sig_yy;
                zz = this.SHELL_DATA.sig_zz;
                xy = this.SHELL_DATA.sig_xy;
                yz = this.SHELL_DATA.sig_yz;
                zx = this.SHELL_DATA.sig_zx;
                this.SHELL_DATA.stress_vm = sqrt(0.5 * ...
                    ((xx-yy).^2 + (yy-zz).^2 + (zz-xx).^2 + 6*(xy.^2+yz.^2+zx.^2)));
            end
        end
        function parseFileContents(this, inStr)
            
            %%
            % Find the timestep anchors throughout the file
            tStepPattern = ['t i m e  s t e p\s*(\d)+\s+\( at time (' ...
                this.sciNumRegexpPattern ') \)'];
            [timestepInds,~,~,~,te] = regexp(inStr,tStepPattern,'lineanchors');
            te = cat(1,te{:});
            timestepArr = str2num(char(te(:,2))); %#ok<ST2NM>
            nTimesteps = length(timestepArr);
            
            %%
            % First check the string chunk between first two timesteps to get a
            % template for which channels/elements to expect in rest of file
            if isempty(timestepArr)
                return
            elseif isscalar(timestepArr)
                inStrA = inStr(timestepInds(1):end);
            else
                inStrA = inStr(timestepInds(1):timestepInds(2));
            end
            
            % Start a SHELL_DATA table
            this.SHELL_DATA = array2table(timestepArr ,'Var',{'timestep'});
            
            % Find any header (stress) lines
            [strsStarts,strsEnds] = regexp(inStrA,' ipt-shl  stress.*?\r\n\r\n');
            if ~isempty(strsStarts)
                stressStr = inStrA(strsStarts:strsEnds);
                
                % Fetch headers
                stressHdrs2line = stressStr(bsxfun(@plus,0:83, [20; 125]));
                stressHdrsCellStrs = arrayfun(@(i)stressHdrs2line(:,(1:12) + (i-1)*12),1:size(stressHdrs2line,2)/12,'Un',0);
                stressHdrs = cellfun(@(tmp)matlab.lang.makeValidName(reshape(tmp',1,[])), stressHdrsCellStrs,'Un',0);
                nChannels = length(stressHdrs);
                
                % Fetch elem and mat Ids
                [elFrom,~,~,~,elToks] = regexp(stressStr,'^\s*(\d+)-\s*(\d+)\s$','lineanchors');
                elToks = cat(1,elToks{:});
                % We have an Nelem-by-2 cell of integer strings. Get ints.
                shellIdsMatIds = reshape(sscanf(sprintf('%s ',elToks{:}),'%d'),[],2);
                this.SHELL_ELEM_INFO = array2table(shellIdsMatIds,...
                    'Var',{'ELEM_ID','MAT_NO'});
                nElems = size(shellIdsMatIds,1);
                
                % Count how many integration points per element (note we
                % are presuming all elements have same number, things will
                % probably break if this is not true)
                if nElems>1
                    elemStr = stressStr(1:elFrom(2));
                else
                    elemStr = stressStr;
                end
                % Number of integration points is the number of lines like
                % 1-    2 elastic...
                % 2-    2 elastic...
                nIP = length(regexp(elemStr,'\d+-\s*\d+\s*[a-zA-Z]'));
                
                % We now know the number of elements and the number of
                % integration points. Build the string format specifier.
                nChNL = 2;
                nChElemLine = 16 + nChNL;
                nChIPLine = 103 + nChNL;
                nChElem = nChElemLine + nIP*nChIPLine;
                fmtChannels = repmat(' %f',1,nChannels);
                fmtIPline = ['%*u- %*u elastic' fmtChannels];
                fmtElem = ['%*u- %*u ' repmat(fmtIPline,1,nIP)];
                
                % Gather stress as channels-by-IP-by-elem-by-time array
                stressData = zeros(nChannels, nIP, nElems, nTimesteps,'single');
                for i = 1:nTimesteps
                    tmpStr = inStr(timestepInds(i) + 291 + (1:nChElem*nElems));
                    stressData(:,:,:,i) = reshape(sscanf(tmpStr,fmtElem),nChannels,nIP,nElems);
                end
                
            end
            
            % Unpack to shell data table
            for hdrNo = 1:length(stressHdrs)
                this.SHELL_DATA.(stressHdrs{hdrNo}) = permute(stressData(hdrNo,:,:,:),[4 3 2 1]);
            end
            
            %% Find any shell strain lines
            strnStarts = regexp(inStr,' strains \(.*?\r\n\r\n','once');
            if strnStarts
                % Fetch strain headers
                strainHdrs = matlab.lang.makeValidName(strsplit(strtrim(...
                    inStr(strnStarts+(20:100))),' '));
                nChannels = length(strainHdrs);
                
                % Build the string format per element
                nChElemLine = 16 + nChNL;
                nChIPLine = 89 + nChNL;
                nChElem = nChElemLine + nIP*nChIPLine;
                fmtChannels = repmat(' %f',1,nChannels);
                fmtIPline = ['%*s ipt' fmtChannels];
                fmtElem = ['%*u- %*u ' repmat(fmtIPline,1,nIP)];
                offset = strnStarts - timestepInds(1) + 244;
                
                % Gather strains as channels-by-IP-by-elem-by-time array
                strainData = zeros(nChannels, nIP, nElems, nTimesteps,'single');
                for i = 1:nTimesteps
                    tmpStr = inStr(timestepInds(i) + offset + (1:nChElem*nElems));
                    strainData(:,:,:,i) = reshape(sscanf(tmpStr,fmtElem),nChannels,nIP,nElems);
                end
                
                % Unpack strains to shell data table
                for hdrNo = 1:length(strainHdrs)
                    this.SHELL_DATA.(strainHdrs{hdrNo}) = permute(strainData(hdrNo,:,:,:),[4 3 2 1]);
                end
            end
            
            %% Find BEAM elements
            
            % Pick out every beam number line
            beamPattern = '^ beam/truss # =\s*(\d+)\s*part ID  =\s*(\d+)\s*material type=\s*(\d+)\s*$';
            [ba,bb,~,~,be] = regexp(inStr,beamPattern,'lineanchors');
            if ~isempty(ba)
                be = cat(1,be{:});
                
                % Extract an index of the element numbers and the part/mat they have
                allBeamElNos = str2num(char(be(:,1))); %#ok<ST2NM>
                [unqBeamElNos,unqBeam1sts,beamNoGrps] = unique(allBeamElNos,'stable');
                unqBeamElPartMatNos = [unqBeamElNos cellfun(@str2double,be(unqBeam1sts,2:3))];
                
                
                % Counts of the variables output from beams
                nTimesteps = length(timestepArr);
                nBeamRes = 6;
                nElems = length(unqBeamElNos);
                
                % Which timestep was each beam line belonging to?
                beamTstepGrp = interp1(timestepInds,1:length(timestepInds),ba(:),'previous','extrap');
                
                % We know the pattern of resultants immediately after beam numbers, so we
                % can just extract that text directly via an offset index:
                % % resultants      axial    shear-s    shear-t    moment-s   moment-t   torsion
                % %            -1.622E-01  1.623E-01  1.564E+01 -4.023E-02 -1.297E-04  2.992E-03
                %
                C = str2num(inStr(bsxfun(@plus,(90:157),bb(:)))); %#ok<ST2NM>
                
                % Make a NaN matrix in case some elements were only output at certain
                % timesteps
                beamEloutMat = nan(nTimesteps, nBeamRes, nElems);
                for i = 1:size(C,1)
                    beamEloutMat(beamTstepGrp(i),:,beamNoGrps(i)) = C(i,:);
                end
                
                % Fetch beam element output names
                [~,~,~,~,beamResNames] = regexp(inStr,' resultants(\s+([^\s+]+))+\s*$','match','once','lineanchors');
                beamResNames = matlab.lang.makeValidName(strsplit(strtrim(beamResNames{1}),' '));
                
                this.BEAM_ELEM_INFO = array2table(unqBeamElPartMatNos,'Var',{'ELEM_ID','PART_ID','MAT_ID'});
                beamT = array2table(timestepArr(:),'Var',{'time'});
                for t = 1:length(beamResNames)
                    beamT.(beamResNames{t}) = permute(beamEloutMat(:,t,:),[1 3 2]);
                end
                this.BEAM_DATA = beamT;
            end
        end
    end
end