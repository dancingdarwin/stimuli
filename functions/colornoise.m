function ex = colornoise(ex, replay)
%
% ex = colornoise(ex, replay)
%
% Required parameters:
%   length : float (length of the experiment in minutes)
%   framerate : float (rough framerate, in Hz)
%   ndims : [int, int] (dimensions of the stimulus)
%   mode: 'spatial' (for 2D pink noise independently drawn for each image
%         'temporal' (for each pixel independently drawn, with pink noise
%         in time domain)
%         'spatiotemporal' (for pink noise in both domains)
%   beta: power law in one dimension (-1 for pink, -2 for brown, etc.)
%
% Optional parameters:
%   seed : int (for the random number generator. Default: 0)
%
% Runs a receptive field mapping stimulus

if replay
    
    % load experiment properties
    numframes = ex.numframes;
    me = ex.params;
    
    % set the random seed
    rs = getrng(me.seed);
    
else
    
    % shortcut for parameters
    me = ex.stim{end}.params;
    
    % initialize the VBL timestamp
    vbl = GetSecs();
    
    % initialize random seed
    if isfield(me, 'seed')
        rs = getrng(me.seed);
    else
        rs = getrng();
    end
    ex.stim{end}.seed = rs.Seed;
    
    % compute flip times from the desired frame rate and length
    if me.framerate > ex.disp.frate
        error('Your monitor does not support a frame rate higher than %i Hz', ex.disp.frate);
    end
    flipsPerFrame = round(ex.disp.frate / me.framerate);
    ex.stim{end}.framerate = 1 / (flipsPerFrame * ex.disp.ifi);
    flipint = ex.disp.ifi * (flipsPerFrame - 0.25);
    
    % store the number of frames
    numframes = ceil((me.length * 60) * ex.stim{end}.framerate);
    ex.stim{end}.numframes = numframes;
    
    % store timestamps
    ex.stim{end}.timestamps = zeros(ex.stim{end}.numframes,1);
    
end

%% Generate Stimulus Pixels
if strcmp(me.mode, 'temporal')
    gen = dsp.ColoredNoise('InverseFrequencyPower',me.beta,'Seed',me.seed,...
        'SamplesPerFrame',numframes,'NumChannels',prod(me.ndims));
    frames = reshape(transpose(gen.step()),me.ndims(1),me.ndims(2),numframes);
elseif strcmp(me.mode, 'spatial')
    frames = zeros(me.ndims(1),me.ndims(2),numframes);
    for fi = 1:numframes
        frames(:,:,fi) = stPattern(me.ndims,-me.beta);
    end
elseif strcmp(me.mode, 'spatiotemporal')
    frames = stPattern([me.ndims numframes],-me.beta);
    disp(frames(:,:,10))
else
    error(['Mode ' me.dist ' not recognized! Must be temporal, spatial, or spatiotemporal.']);
end

%% Normalize Stimulus Pixels
min_val = min(frames(:));
max_val = max(frames(:));
frames = (frames - min_val) / (max_val-min_val) * me.contrast;

%% loop over frames
for fi = 1:numframes
    frame = frames(:,:,fi);
    if replay
        % write the frame to the hdf5 file
        h5write(ex.filename, [ex.group '/stim'], uint8(me.gray * frame), [1, 1, fi], [me.ndims, 1]);
        
    else
        
        % make the texture
        texid = Screen('MakeTexture', ex.disp.winptr, uint8(ex.disp.white * frame));
        
        % draw the texture, then kill it
        Screen('DrawTexture', ex.disp.winptr, texid, [], ex.disp.dstrect, 0, 0);
        Screen('Close', texid);
        
        % update the photodiode with the top left pixel on the first frame
        if fi == 1
            pd = ex.disp.white;
        else
            pd = ex.disp.pdscale * ex.disp.gray * frame(1);
        end
        Screen('FillOval', ex.disp.winptr, pd, ex.disp.pdrect);
        
        % flip onto the scren
        Screen('DrawingFinished', ex.disp.winptr);
        vbl = Screen('Flip', ex.disp.winptr, vbl + flipint);
        
        % save the timestamp
        ex.stim{end}.timestamps(fi) = vbl;
        
        % check for ESC
        ex = checkkb(ex);
        if ex.key.keycode(ex.key.esc)
            fprintf('ESC pressed. Quitting.')
            break;
        end
        
    end
    
end

end
