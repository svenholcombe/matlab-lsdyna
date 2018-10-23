classdef ELEMENT_SOLID < lsdyna.keyword.card
    %lsdyna.keyword.NODE
    
    properties (Constant)
        KeywordMatch = "ELEMENT_SOLID";
    end
    properties (Constant, Hidden)
        DependentCards = "NODE";
    end
    
    properties
        ElemData = table;
    end
    
    %% CONSTRUCTOR
    methods
        function newCard = ELEMENT_SOLID(basicCard)
            % Allow empty constructor
            if ~nargin
                return;
            end
            % Elseif isa basicCard then convert
            newCard = basicCard.assignPropsToSubclass(newCard);
            % Else call superclass constructor on varargin
        end
        
        function C = parseData(C)
            % Parse the string data and populate this card's numeric data
            
            % Supply definitions for each line of any cards represented by
            % this class
            FLDSsolid = cell2table({
                'eid' 'pid' 'n1' 'n2' 'n3' 'n4' 'n5' 'n6' 'n7' 'n8'
                8         8    8    8    8    8    8    8    8    8
                "d"     "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"  "d"
                }','Var',{'fld','size','fmt'});
            
            lineDefns = cell2table({
                "ELEMENT_SOLID"             1 @(i)true(size(i)) FLDSsolid
                }, 'Var', {'keyword','lineNo','lineMatchFcn','FLDS'});
            %% Populate the line definitions with strings from each card
            % We will group into individual cards first, then separate into
            % the separate lines within each card
            [unqKeywords,~,keyGrp] = unique(lineDefns.keyword);
            unqKeyT = table(unqKeywords,'Var',{'keyword'});
            for grpNo = 1:length(unqKeywords)
                m = [C.Keyword]==unqKeywords(grpNo);
                unqKeyT.cardMask(grpNo,:) = m(:)';
                unqKeyT.strs(grpNo,1) = {cat(1,C(m).ActiveString)};
                unqKeyT.lineCounts(grpNo,1) = {cellfun(@numel,{C(m).ActiveString})};
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
                strsAsCharMat = char(strs);

                FLDS.startChar = 1+[0;cumsum(FLDS.size(1:end-1))];
                FLDS.endChar = FLDS.startChar + FLDS.size - 1;
                FLDS.charInds = arrayfun(@(from,to)...
                    from:to,FLDS.startChar,FLDS.endChar,'Un',0);
                nFlds = size(FLDS,1);
                fmtStr = cell2mat(strcat(...
                    '%', arrayfun(@num2str,FLDS.size,'Un',0), FLDS.fmt)');

                % Parse formatted text by column nos
                sizeBasedText = strsAsCharMat(:,1:FLDS.endChar(end))';
                sizeBasedText(end+1:max(FLDS.endChar),:) = ' ';
                for i = 1:nFlds
                    emptyMask = all(sizeBasedText(FLDS.charInds{i},:) == ' ',1);
                    sizeBasedText(FLDS.endChar(i),emptyMask) = '0';
                end
                RAWDATA = reshape(sscanf(sizeBasedText,fmtStr), nFlds,[])';
                TABLE_DATA = array2table(RAWDATA,'Var',FLDS.fld);
                % Change digit-specified fields to ints (CAREFUL! we don't
                % want to change deliberately negative integers so this bit
                % should coincide with the keyword card definitions. For
                % element_[X] there are no negative element/node ids)
                for fldNo = find(strcmp(FLDS.fmt,'d'))'
                    fld = FLDS.fld{fldNo};
                    TABLE_DATA.(fld) = uint32(TABLE_DATA.(fld));
                end
                lineDefns.DATA_TABLE{mNo,1} = TABLE_DATA;
            end
            
            %% Combine lines into cards
            for grpNo = 1:length(unqKeywords)
                % Concatenate lines into one wide data table
                DT = [lineDefns.DATA_TABLE{keyGrp==grpNo}];
                % Merge nodeId vars into one var and drop unused nodes
                nidFlds = ~cellfun(@isempty,...
                    regexp(DT.Properties.VariableNames,'^n\d+$'));
                DT = mergevars(DT,nidFlds,'NewVariableName','nids');
                DT.nids(:,all(DT.nids==0,1)) = [];
                % Merge also for thickness (t1,t2,etc.) vars
                thicFlds = ~cellfun(@isempty,...
                    regexp(DT.Properties.VariableNames,'^t\d+$'));
                if any(thicFlds)
                    DT = mergevars(DT,thicFlds,'NewVariableName','thic');
                    DT.thic(:,all(DT.thic==0,1)) = [];
                end
                
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