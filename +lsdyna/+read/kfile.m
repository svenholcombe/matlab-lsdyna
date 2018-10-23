function [PART, NODE, ELEMENT_SHELL, ELEMENT_SOLID, ELEMENT_SHELL_THICKNESS] = kfile(kFileStr)
% UNDER CONSTRUCTION! This file contains some basic logic to parse a dyna
% k-file but the overall API for reading and storing that information is
% not complete.

% kFileStr = 'GHBMC_M50-O_v4-5_20160901.k';

% Read the kfile and extract separate cards
X = fileread(kFileStr);
[toks,cardStarts] = regexp(X,'^\*([\w_]+)','lineanchors','tokens');
cardNames = cat(1,toks{:});
cardEnds = [cardStarts(2:end)-2 length(X)];
cardsFullText = arrayfun(@(from,to)X(from:to),cardStarts,cardEnds,'Un',0);

%% Get PARTS
nl = char([13    10]);
anyCmnt = ['\s*?(?:' nl '\s*\$[^' nl ']*)*'];
m = strcmpi('part',cardNames);
cardToks = regexpi(cardsFullText(m),['^\*PART' anyCmnt nl '([^\n]*)' anyCmnt nl '([^\n]*)'],'tokens');
cardToks = cat(1,cardToks{:});
cardToks = cat(1,cardToks{:});
PART = cell2table(strtrim(cardToks(:,1)),'Var',{'Title'});
cardOpts = {'pid','secid','mid','eosid','hgid','grav','adpopt','tmid'};
for c = 1:length(cardOpts)
    PART.(cardOpts{c}) = uint32(cellfun(@(x)str2double(x((1:10)+10*(c-1))),cardToks(:,2)));
end

%% Get NODES
m = strcmpi('node',cardNames);
nodeFullText = regexp([cardsFullText{m}],'^\s*\d[^\r\n]*','match','lineanchors')';
nodeFullTextChar = char(nodeFullText);
nNodes = size(nodeFullTextChar,1);

FLDS = cell2table({
    'nid' 'x'  'y'  'z' 'tc' 'rc'
    8      16   16   16    8   8
    'd'   'f'  'f'  'f'  'f'  'f'
    }','Var',{'fld','size','fmt'});
FLDS.startChar = 1+[0;cumsum(FLDS.size(1:end-1))];
FLDS.endChar = FLDS.startChar + FLDS.size - 1;
FLDS.charInds = arrayfun(@(from,to)from:to,FLDS.startChar,FLDS.endChar,'Un',0);
nFlds = size(FLDS,1);
fmtStr = cell2mat(strcat('%', arrayfun(@num2str,FLDS.size,'Un',0), FLDS.fmt)');
hasCommasMask = any(nodeFullTextChar==',',2);
NODEDATA = zeros(nNodes,nFlds);

%% Parse formatted text by column nos

sizeBasedText = nodeFullTextChar(~hasCommasMask,1:FLDS.endChar(end))';
sizeBasedText(end+1:max(FLDS.endChar),:) = ' ';

for i = 1:nFlds
    emptyMask = all(sizeBasedText(FLDS.charInds{i},:) == ' ',1);
    sizeBasedText(FLDS.endChar(i),emptyMask) = '0';
end
nodDataFromFormattedText = reshape(sscanf(sizeBasedText,fmtStr), nFlds,[])';
NODEDATA(~hasCommasMask,:) = nodDataFromFormattedText;

%% Parse formatted text by commas
textWithCommas = nodeFullTextChar(hasCommasMask,:);
nRows = size(textWithCommas,1);
nCols = size(textWithCommas,2);
[colNo,rowNo] = find(textWithCommas'==',');
commasCell = accumarray(rowNo,colNo,[nRows 1],@(x){x});
fldFromCell = cellfun(@(c)[1;c+1],commasCell,'Un',0);
fldToCell = cellfun(@(c)[c-1;nCols],commasCell,'Un',0);
nodeDataFromCommas = zeros(nRows,nFlds);
for r = 1:nRows
    for i = 1:length(fldFromCell{r})
        nodeDataFromCommas(r,i) = str2double(textWithCommas(r,fldFromCell{r}(i):fldToCell{r}(i)));
    end
end
NODEDATA(hasCommasMask,:) = nodeDataFromCommas;

%% Make the NODE table
NODE = array2table(NODEDATA,'Var',FLDS.fld);
NODE.nid = uint32(NODE.nid);
NODE.tc = uint8(NODE.tc);
NODE.rc = uint8(NODE.rc);

%% Get SHELL ELEMENTS

FLDSshell = cell2table({
    'eid' 'pid' 'n1' 'n2' 'n3' 'n4' 'n5' 'n6' 'n7' 'n8'
    8         8    8    8    8    8    8    8    8    8
    'd'     'd'  'd'  'd'  'd'  'd'  'd'  'd'  'd'  'd'
    }','Var',{'fld','size','fmt'});
FLDSshellThick = cell2table({
    'eid' 'pid' 'n1' 'n2' 'n3' 'n4' 'n5' 'n6' 'n7' 'n8' 't1' 't2' 't3' 't4' 'beta'
    8         8    8    8    8    8    8    8    8    8   16   16   16   16     16
    'd'     'd'  'd'  'd'  'd'  'd'  'd'  'd'  'd'  'd'  'f'  'f'  'f'  'f'    'f'
    }','Var',{'fld','size','fmt'});

shllTypeTab = cell2table({
    "ELEMENT_SHELL"               FLDSshell         
    "ELEMENT_SHELL_THICKNESS"     FLDSshellThick
    }, 'Var', {'keyword','FLDS'});

for mNo = 1:size(shllTypeTab,1)
    
    m = strcmpi(shllTypeTab.keyword(mNo),cardNames);
    shellFullText = regexp([cardsFullText{m}],'^\s*[^\$\*][^\r\n]*','match','lineanchors')';
    shellFullTextChar = char(shellFullText);
    % For shell thickness elems just join lines 1 (nodes) and 2 (thickness)
    if shllTypeTab.keyword(mNo)=="ELEMENT_SHELL_THICKNESS"
        shellFullTextChar = [shellFullTextChar(1:2:end,:) shellFullTextChar(2:2:end,:)];
    end
    nShells = size(shellFullTextChar,1);
    FLDS = shllTypeTab.FLDS{mNo};
    FLDS.startChar = 1+[0;cumsum(FLDS.size(1:end-1))];
    FLDS.endChar = FLDS.startChar + FLDS.size - 1;
    FLDS.charInds = arrayfun(@(from,to)from:to,FLDS.startChar,FLDS.endChar,'Un',0);
    nFlds = size(FLDS,1);
    fmtStr = cell2mat(strcat('%', arrayfun(@num2str,FLDS.size,'Un',0), FLDS.fmt)');
    if all(strcmp(FLDS.fmt,'d'))
        SHELLDATA = zeros(nShells,nFlds,'uint32');
    else
        SHELLDATA = zeros(nShells,nFlds);
    end
    hasCommasMask = any(shellFullTextChar==',',2);
    if any(hasCommasMask)
        warning('Comma-separated ELEMENT cards not yet supported')
    end
    
    % Parse formatted text by column nos
    sizeBasedText = shellFullTextChar(~hasCommasMask,1:FLDS.endChar(end))';
    sizeBasedText(end+1:max(FLDS.endChar),:) = ' ';
    for i = 1:nFlds
        emptyMask = all(sizeBasedText(FLDS.charInds{i},:) == ' ',1);
        sizeBasedText(FLDS.endChar(i),emptyMask) = '0';
    end
    shlDataFromFormattedText = reshape(sscanf(sizeBasedText,fmtStr), nFlds,[])';
    SHELLDATA(~hasCommasMask,:) = shlDataFromFormattedText;
    
    SHELL_TABLE = array2table(SHELLDATA,'Var',FLDS.fld);
    % Change digit-specified fields to ints
    for fldNo = find(strcmp(FLDS.fmt,'d'))'
        fld = FLDS.fld{fldNo};
        SHELL_TABLE.(fld) = uint32(SHELL_TABLE.(fld));
    end
    
    % Create nids as an N-by-nodes matrix instead of individual fields
    nidFlds = ~cellfun(@isempty,regexp(SHELL_TABLE.Properties.VariableNames,'^n\d+$'));
    SHELL_TABLE = mergevars(SHELL_TABLE,nidFlds,'NewVariableName','nids');
    % Drop node ids that are unused
    SHELL_TABLE.nids(:,all(SHELL_TABLE.nids==0,1)) = [];
    % Merge thickness fields also
    thicFlds = ~cellfun(@isempty,regexp(SHELL_TABLE.Properties.VariableNames,'^t\d+$'));
    if any(thicFlds)
        SHELL_TABLE = mergevars(SHELL_TABLE,thicFlds,'NewVariableName','thic');
        % Drop node ids that are unused
        SHELL_TABLE.thic(:,all(SHELL_TABLE.thic==0,1)) = [];
    end
    shllTypeTab.DATA{mNo,1} = SHELL_TABLE;
end

[ELEMENT_SHELL,ELEMENT_SHELL_THICKNESS] = shllTypeTab.DATA{:};

%% Get SOLID ELEMENTS
m = strcmpi('ELEMENT_SOLID',cardNames);
shellFullText = regexp([cardsFullText{m}],'^\s*\d[^\r\n]*','match','lineanchors')';
shellFullTextChar = char(shellFullText);
nShells = size(shellFullTextChar,1);
FLDS = cell2table({
    'eid' 'pid' 'n1' 'n2' 'n3' 'n4' 'n5' 'n6' 'n7' 'n8'
    8         8    8    8    8    8    8    8    8    8
    'd'     'd'   'd' 'd'  'd'  'd'  'd'  'd'  'd'  'd'
    }','Var',{'fld','size','fmt'});
FLDS.startChar = 1+[0;cumsum(FLDS.size(1:end-1))];
FLDS.endChar = FLDS.startChar + FLDS.size - 1;
FLDS.charInds = arrayfun(@(from,to)from:to,FLDS.startChar,FLDS.endChar,'Un',0);
nFlds = size(FLDS,1);
fmtStr = cell2mat(strcat('%', arrayfun(@num2str,FLDS.size,'Un',0), FLDS.fmt)');
SOLIDDATA = zeros(nShells,nFlds,'uint32');

hasCommasMask = any(shellFullTextChar==',',2);
if any(hasCommasMask)
    % Parse element text separated by commas
    textWithCommas = shellFullTextChar(hasCommasMask,:);
    nRows = size(textWithCommas,1);
    nCols = size(textWithCommas,2);
    [colNo,rowNo] = find(textWithCommas'==',');
    commasCell = accumarray(rowNo,colNo,[nRows 1],@(x){x});
    fldFromCell = cellfun(@(c)[1;c+1],commasCell,'Un',0);
    fldToCell = cellfun(@(c)[c-1;nCols],commasCell,'Un',0);
    shellDataFromCommas = zeros(nRows,nFlds);
    % THIS SECTION IS SLOW! Can easily be sped up via vectorisation
    for r = 1:nRows
        for i = 1:length(fldFromCell{r})
            shellDataFromCommas(r,i) = str2double(textWithCommas(r,fldFromCell{r}(i):fldToCell{r}(i)));
        end
    end
    SOLIDDATA(hasCommasMask,:) = shellDataFromCommas;
end


% Parse formatted text by column nos
sizeBasedText = shellFullTextChar(~hasCommasMask,1:FLDS.endChar(end))';
sizeBasedText(end+1:max(FLDS.endChar),:) = ' ';
for i = 1:nFlds
    emptyMask = all(sizeBasedText(FLDS.charInds{i},:) == ' ',1);
    sizeBasedText(FLDS.endChar(i),emptyMask) = '0';
end
shlDataFromFormattedText = reshape(sscanf(sizeBasedText,fmtStr), nFlds,[])';
SOLIDDATA(~hasCommasMask,:) = shlDataFromFormattedText;
ELEMENT_SOLID = array2table(SOLIDDATA,'Var',FLDS.fld);
ELEMENT_SOLID.nids = table2array(ELEMENT_SOLID(:,~cellfun(@isempty,regexp(ELEMENT_SOLID.Properties.VariableNames,'^n\d+$'))));
ELEMENT_SOLID(:,~cellfun(@isempty,regexp(ELEMENT_SOLID.Properties.VariableNames,'^n\d+$'))) = [];