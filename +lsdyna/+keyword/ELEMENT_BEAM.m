classdef ELEMENT_BEAM < lsdyna.keyword.card
    %lsdyna.keyword.ELEMENT_BEAM
    
    properties (Constant)
        KeywordMatch = "ELEMENT_BEAM";
        LineDefinitions = ...
            lsdyna.keyword.utils.cardLineDefinition("ELEMENT_BEAM");
    end
    properties (Constant, Hidden)
        DependentCards = "NODE";
    end
    
    properties
        ElemData = table;
    end
    
    %% CONSTRUCTOR
    methods
        function newCard = ELEMENT_BEAM(basicCard)
            % Allow empty constructor
            if ~nargin
                return;
            end
            % Elseif isa basicCard then convert
            newCard = basicCard.assignPropsToSubclass(newCard);
            % Else call superclass constructor on varargin
        end
        
        function C = arr_stringToData(C)
            % Parse the string data and populate this card's numeric data
            
            % Supply definitions for each line of any cards represented by
            % this class
            lineDefns = C(1).LineDefinitions;
            
            %% Populate the line definitions with strings from each card
            % We will group into individual cards first, then separate into
            % the separate lines within each card
            [unqKeywords,~,keyGrp] = unique(lineDefns.keyword);
            unqKeyT = table(unqKeywords,'Var',{'keyword'});
            unqKeyT.strs(:,1) = {strings(0,1)};
            for grpNo = 1:length(unqKeywords)
                m = [C.Keyword]==unqKeywords(grpNo);
                unqKeyT.cardMask(grpNo,:) = m(:)';
                if any(m)
                    unqKeyT.strs(grpNo) = {cat(1,C(m).ActiveString)};
                    unqKeyT.lineCounts(grpNo,1) = {cellfun(@numel,{C(m).ActiveString})};
                end
            end
            for mNo = 1:size(lineDefns,1)
                grpNo = keyGrp(mNo);
                fullStrs = unqKeyT.strs{grpNo};
                lineMask = lineDefns.lineMatchFcn{mNo}(1:length(fullStrs));
                FLDS = lineDefns.FLDS{mNo};
                lineDefns.strs(mNo,1) = { % Convert comma-separated to spaces
                    C.convertCommaSepStrsToSpacedStrs(fullStrs(lineMask),FLDS.size)};
            end
            
            %% Convert each line to data
            for mNo = 1:size(lineDefns,1)
                strs = lineDefns.strs{mNo};
                FLDS = lineDefns.FLDS{mNo};
                
                % Turn comma-sep lines into spaced lines and read the data
                strs = C.convertCommaSepStrsToSpacedStrs(strs,FLDS.size);
                SHELLDATA = C.convertSpacedStrsToMatrix(strs,FLDS);
                SHELL_TABLE = array2table(SHELLDATA,'Var',FLDS.fld);
                % Change digit-specified fields to ints (CAREFUL! we don't
                % want to change deliberately negative integers so this bit
                % should coincide with the keyword card definitions. For
                % shells there are no negative element/node ids)
                for fldNo = find(strcmp(FLDS.fmt,'d'))'
                    fld = FLDS.fld{fldNo};
                    SHELL_TABLE.(fld) = uint32(SHELL_TABLE.(fld));
                end
                lineDefns.DATA_TABLE{mNo,1} = SHELL_TABLE;
            end
            
            %% Combine lines into cards
            % Here we have an interesting problem. The ELEMENT_SHELL card
            % can be concatenated vertically with line 1 from the
            % ELEMENT_SHELL_THICKNESS card, or the two lines from
            % ELEMENT_SHELL_THICKNESS can be concatenated horizontally. OR,
            % we could add dummy thickness variables to the ELEMENT_SHELL
            % cards so that they can all be concatenated. I'm not sure what
            % is best. Let's stick with cards being unique.
            for grpNo = find(~cellfun(@isempty,unqKeyT.strs)')
                % Concatenate lines into one wide data table
                DT = [lineDefns.DATA_TABLE{keyGrp==grpNo}];
                % Merge nodeId vars into one var and drop unused nodes
                nidFlds = ~cellfun(@isempty,...
                    regexp(DT.Properties.VariableNames,'^n\d+$'));
                DT = mergevars(DT,nidFlds,'NewVariableName','nids');
                DT.nids(:,all(DT.nids==0,1)) = [];
                
                % For cards with multiple lines that are hori-concatenated
                % the row numbers into the data table must be the total
                % line numbers divided by the number of lines per card
                nLines = nnz(keyGrp==grpNo);
                rowsPerCard = unqKeyT.lineCounts{grpNo}/nLines;
                cardsEndAt = cumsum(rowsPerCard);
                cardsStartAt = [1 cardsEndAt(1:end-1)+1];
                % Push individual separate data tables into each card
                CARDset = arrayfun(@(from,to)...
                    DT(from:to,:),cardsStartAt,cardsEndAt,'Un',0);
                [C(unqKeyT.cardMask(grpNo,:)).ElemData] = CARDset{:};
            end
        end
    end
end