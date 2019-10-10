function [PART, NODE, ELEMENT_SHELL, ELEMENT_SOLID, ELEMENT_SHELL_THICKNESS] = kfile(kFileStr)
% UNDER CONSTRUCTION! This file contains some basic logic to parse a dyna
% k-file but the overall API for reading and storing that information is
% not complete.

% kFileStr = 'GHBMC_M50-O_v4-5_20160901.k';

% Read the kfile and extract separate cards
if isa(kFileStr,'lsdyna.keyword.file')
    F = kFileStr;
else
    F = lsdyna.keyword.file.readKfile(kFileStr);
end
[~, ~, ~, ~, ELEMENT_SHELL_THICKNESS] = deal([]);
%%
C_NODE = F.Cards(startsWith([F.Cards.Keyword],"NODE"));
NODE = cat(1,C_NODE.NodeData);
C_PART = F.Cards(startsWith([F.Cards.Keyword],"PART"));
PART = table([C_PART.Heading]',uint32([C_PART.PID]'),uint32([C_PART.SID]'),uint32([C_PART.MID]'),'Var',{
    'heading' 'pid' 'secid' 'mid'});
C_ELEM = F.Cards(startsWith([F.Cards.Keyword],"ELEMENT_SHELL_THICKNESS"));
if ~isempty(C_ELEM)
    ELEMENT_SHELL_THICKNESS = cat(1,C_ELEM.ElemData);
end
C_ELEM = F.Cards([F.Cards.Keyword]=="ELEMENT_SHELL");
ELEMENT_SHELL = cat(1,C_ELEM.ElemData);
C_ELEM = F.Cards(startsWith([F.Cards.Keyword],"ELEMENT_SOLID"));
ELEMENT_SOLID = cat(1,C_ELEM.ElemData);




