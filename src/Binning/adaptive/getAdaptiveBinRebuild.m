function out = getAdaptiveBinRebuild(raw,roiCoord,binLevels)
%=============================================================================================================
%
% @file     getAdaptiveBinRebuild.m
% @author   Matthias Klemm <Matthias_Klemm@gmx.net>
% @version  1.0
% @date     January, 2016
%
% @section  LICENSE
%
% Copyright (C) 2015, Matthias Klemm. All rights reserved.
%
% Redistribution and use in source and binary forms, with or without modification, are permitted provided that
% the following conditions are met:
%     * Redistributions of source code must retain the above copyright notice, this list of conditions and the
%       following disclaimer.
%     * Redistributions in binary form must reproduce the above copyright notice, this list of conditions and
%       the following disclaimer in the documentation and/or other materials provided with the distribution.
%     * Neither the name of FLIMX authors nor the names of its contributors may be used
%       to endorse or promote products derived from this software without specific prior written permission.
%
% THIS SOFTWARE IS PROVIDED BY THE COPYRIGHT HOLDERS AND CONTRIBUTORS "AS IS" AND ANY EXPRESS OR IMPLIED
% WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF MERCHANTABILITY AND FITNESS FOR A
% PARTICULAR PURPOSE ARE DISCLAIMED. IN NO EVENT SHALL THE COPYRIGHT OWNER OR CONTRIBUTORS BE LIABLE FOR ANY DIRECT,
% INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT NOT LIMITED TO,
% PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, DATA, OR PROFITS; OR BUSINESS INTERRUPTION)
% HOWEVER CAUSED AND ON ANY THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING
% NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF ADVISED OF THE
% POSSIBILITY OF SUCH DAMAGE.
%
%
% @brief    A function to rebuild the adataptive binning for a certain ROI using previously obtained binning levels per pixel
%
[yR, xR, zR] = size(raw);
out = zeros(size(binLevels,1),size(binLevels,2),zR,'like',raw);
[binXcoord, binYcoord, ~, ~, allMasks] = makeBinMask(100);
raw = reshape(raw,[yR*xR,zR]);
parfor i = 1:size(binLevels,1)
    tmp = out(i,:,:);
    for j = 1:size(binLevels,2)
        idx = moveMaskToPixelPosition(allMasks(:,:,binLevels(i,j)),roiCoord(3)+i-1,roiCoord(1)+j-1,yR,xR,binXcoord, binYcoord);
        %idx = getAdaptiveBinningIndex(roiCoord(3)+i-1,roiCoord(1)+j-1,binLevels(i,j),yR,xR,binXcoord, binYcoord, binRho, binRhoU);
        %tmp(1,j,:) = sum(raw(bsxfun(@plus, idx, int32(yR) * int32(xR) * ((1:int32(zR))-1))),1,'native')';
        tmp(1,j,:) = sum(raw(idx, :),1,'native')';
    end
    out(i,:,:) = tmp;
end