classdef file < handle
    %An LS-Dyna keyword file class
    %   Detailed explanation goes here
    
    properties
        Filepath(1,1) string = ""
        Filename(1,1) string = ""
        Preamble(:,1) string = ""
        Cards(:,1) lsdyna.keyword.card_base
    end
    
    %% CONSTRUCTOR
    methods
        function F = file(filename,varargin)
            if ~nargin
                % Make an empty file
                return;
            end
            [F.Filepath,fname,fext] = fileparts(char(filename));
            F.Filename = [fname fext];
            % Add potential custom input
            IP = inputParser;
            IP.addParameter('Cards',[])
            IP.addParameter('Preamble',"")
            IP.parse(varargin{:})
            givenFields = setdiff(IP.Parameters,IP.UsingDefaults);
            for i = 1:length(givenFields)
                fld = givenFields{i};
                F.(fld) = IP.Results.(fld);
            end
            
        end
        
        function makeSpecificCards(F)
            % "Dive down" from the most generic card definition to apply
            % specific card classes to all cards where available
            F.Cards = makeSpecificCards(F.Cards);
        end
        
        function NodeT = getNodesTable(KF)
            % Obtain all node data in a single table
            C = KF.Cards(startsWith([KF.Cards.Keyword],"NODE","ignoreCase",true));
            NodeT = cat(1,C.NodeData);
        end
        function PartT = getPartsTable(KF)
            % Obtain all part data in a single table
            C = KF.Cards(startsWith([KF.Cards.Keyword],"PART","ignoreCase",true));
            PartT = table(uint32([C.PID]'), [C.Heading]', ...
                uint32([C.MID]'), uint32([C.SID]'), C(:), 'Var',{
                'pid','heading','mid','sid','card'});
        end
        function ElemT = getElementsTable(KF)
            %% Obtain all (or most) element data in a single table
            C = KF.Cards(startsWith([KF.Cards.Keyword],"ELEMENT","ignoreCase",true));
            ElemCardKeys = categorical([C.Keyword]');
            ElemCell = arrayfun(@(C)C.ElemData,C,'Un',0,'Err',@(a,b)[]);
            % Note that here we're dropping unknown element types, as well
            % as any element properties other than eid, pid, nids
            nodesPerCell = cellfun(@(x)size(x.nids,2),ElemCell,'Err',@(a,b)0);
            maxNodesCount = max(nodesPerCell);
            for i = 1:numel(ElemCell)
                if isempty(ElemCell{i})
                    continue;
                end
                ElemCell{i}.nids(:,end+1:maxNodesCount) = 0;
                ElemCell{i} = ElemCell{i}(:,["eid" "pid" "nids"]);
                ElemCell{i}.keyword(:,1) = ElemCardKeys(i);
            end
            ElemT = cat(1,ElemCell{:});

            % It will be useful to obtain the TYPE of element, namely TRIA
            % (3 noded 2d triangle), QUAD (4 noded 2d), TETRA (4 noded 3d),
            % PYRAMID (5 noded 3d), HEX (8 noded 3d) or OTHER
            ElemT.elemType(:,1) = categorical("");
            numUnqNodes = ones(height(ElemT),1);
            for nodeNo = 2:maxNodesCount
                isNewNode = ElemT.nids(:,nodeNo) ~= 0 & ...
                    ~any(ElemT.nids(:,nodeNo) == ElemT.nids(:,1:nodeNo-1),2);
                numUnqNodes(isNewNode) = numUnqNodes(isNewNode) + 1;
            end
            ElemT.nodeCount = categorical(numUnqNodes);
            [unqCnts,~,unqGrp] = unique(numUnqNodes);
            isShell = contains(string(ElemT.keyword),"SHELL",'ignoreCase',true);
            isSolid = contains(string(ElemT.keyword),"SOLID",'ignoreCase',true);
            for i = 1:length(unqCnts)
                m = unqGrp==i;
                switch unqCnts(i)
                    case 1
                        ElemT.elemType(m) = categorical("1d");
                    case 2
                        ElemT.elemType(m) = categorical("2d");
                    case 3
                        ElemT.elemType(m & isShell) = categorical("tria");
                        ElemT.elemType(m & ~isShell) = categorical("2d_oriented");
                    case 4
                        ElemT.elemType(m & isShell) = categorical("quad");
                        ElemT.elemType(m & isSolid) = categorical("tetra");
                    case 5
                        ElemT.elemType(m & isSolid) = categorical("pyramid");
                    case 6
                        ElemT.elemType(m & isSolid) = categorical("triprism");
                    case 8
                        ElemT.elemType(m & isSolid) = categorical("hex");
                end
            end
        end
        
        function append(KF, varargin)
            % Append one or more KFILES via concatenating their Cards.
            for i = 1:length(varargin)
                KF.Cards = cat(1,KF.Cards,varargin{i}.Cards);
            end
        end
    end
    
    
    
    methods (Static)
        function F = readKfile(FILE,firstNlines)
            % readKfile(FILE) % Read the keyword FILE
            % readKfile(STRING) % Read the keywords from the given STRING
            % readKfile(...,NLINES) % Read just NLINES lines (for testing)
            
            % Determine the input syntax and read
            if (isStringScalar(FILE) || ischar(FILE)) && strlength(FILE) < 1000
                assert(exist(FILE,'file')>0,"File not found: %s\n",FILE)
                filename = FILE;
                tic
                fprintf("Reading %s ... ", FILE)
                X = string(fileread(FILE));
                fprintf("read %0.0fK chars in %0.2fs.\n", strlength(X)/1000, toc)
            else
                filename = 'Untitled.k';
                X = string(FILE);
            end
            
            % Split into individual lines
            if isscalar(X)
                fprintf("Splitting contents ... ")
                tic
                X = splitlines(X);
                fprintf("found %d lines in %0.2fs.\n", numel(X), toc)
            end            
            
            % Determine where keywords begin
            fprintf("Reading keywords ... ")
            tic
            if nargin<2
                firstNlines = length(X);
            end
            tmp = X(1:firstNlines);
            keywordLineNos = find(startsWith(tmp,'*'));
            fprintf("%d read in %0.2fs\n", numel(keywordLineNos), toc)
            
            % Collect keyword strings and card contents strings
            fprintf("Building keywords list ... ")
            tic
            preComments = tmp(1:keywordLineNos(1)-1);
            keywords = strip(deblank(tmp(keywordLineNos)), 'left',"*");
            cardsStart = keywordLineNos + 1;
            cardsEnd = [keywordLineNos(2:end)-1; length(tmp)];
            cardsCell = arrayfun(@(from,to)tmp(from:to),cardsStart,cardsEnd,'Un',0);
            fprintf(" done in %0.2fs\n", toc)
            
            % Build the card objects
            fprintf("Building basic cards ... ")
            tic
            cards = lsdyna.keyword.card(keywords,cardsCell);
            fprintf("done in %0.2fs\n", toc)
            
            % Build the kfile object and populate it
            F = lsdyna.keyword.file(filename,'Cards',cards,'Preamble',preComments);
            % It's quickest to assign all cards a line number at once
            lineNos = num2cell(uint32(cardsStart));
            [F.Cards.LineNumber] = lineNos{:};
            [F.Cards.File] = deal(F);
            
            fprintf("Building specific cards ... ")
            tic
            F.makeSpecificCards;
            fprintf("done in %0.2fs\n", toc)
            
            F.Cards.stringToData;
            
        end
    end
end

