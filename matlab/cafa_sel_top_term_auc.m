function [sel, bsl, info] = cafa_sel_top_term_auc(K, aucs, naive, blast, reg, isdump)
%CAFA_SEL_TOP_TERM_AUC CAFA select top term-centric AUC
%
% [sel, bsl, info] = CAFA_SEL_TOP_TERM_AUC(K, aucs, naive, blast, reg, isdump);
%
%   Picks the top AUC methods.
%
% Input
% -----
% [double]
% K:      The number of teams/methods to pick.
%
% [cell]
% aucs:   The collected 'term_auc' structures, which has the following fields
%         [char]    .id     (Internel) model of the model
%         [cell]    .term   1-by-m, term ID list
%         [double]  .auc    1-by-m, AUC per term
%         See cafa_eval_term_auc.m, cafa_collect.m
%
% [char]
% naive:  The model id of the naive baseline. E.g. BN4S
%         Could be empty: '' if not interested.
%
% [char]
% blast:  The model id of the blast baseline. E.g. BB4S
%         Could be empty: '' if not interested.
%
% [char]
% reg:    The team register, which has the following columns:
%       * 1. <internalID>
%       * 2. <externalID>
%         3. <teamname>
%       * 4. <type>
%       * 5. <displayname>
%       * 6. <dumpname>
%       * 7. <pi>
%         8. <keyword list>
%       * 9. <assigned color>
%
%         Note:
%         1. The starred columns (*) will be used in this function.
%         2. 'type':  'q'  - qualified
%                     'd'  - disqualified
%                     'n'  - Naive model (baseline 1)
%                     'b'  - BLAST model (baseline 2)
%
% [logical]
% isdump: A switch for using dump name instead of display name.
%         default: false
%
% Output
% ------
% [cell]
% sel:  The bars and related information ready for plotting:
%       .auc_mean [double]  scalar, "bar height".
%       .auc_q05  [double]  scalar, 5% quantiles.
%       .auc_q95  [double]  scalar, 95% quantiles.
%       .auc_std  [double]  scalar, standard deviation
%       .auc_ste  [double]  scalar, standard error (std / sqrt(N))
%       .tag      [cell]    tag of the model.
%       .pi_name  [cell]    name of the PI.
%       .color    [double]  assigned color (1-by-3 RGB tuple).
%
% [cell]
% bsl:  The baseline bars and related information. Each cell has the same
%       structure as 'sel'.
%
% [struct]
% info: Extra information.
%       .all_mid  [cell]  model name of all participating models.
%       .top_mid  [cell]  model name of top K models (ranked from 1 to K)
%
% Dependency
% ----------
%[>]cafa_team_register.m
%
% See Also
% --------
%[>]cafa_collect.m
%[>]cafa_eval_term_auc.m

  % check inputs {{{
  if nargin ~= 6
    error('cafa_sel_top_term_auc:InputCount', 'Expected 6 inputs.');
  end

  % K
  validateattributes(K, {'double'}, {'nonnegative', 'integer'}, '', 'K', 1);

  % aucs
  validateattributes(aucs, {'cell'}, {'nonempty'}, '', 'aucs', 2);

  % naive
  validateattributes(naive, {'char'}, {}, '', 'naive', 3);

  % blast
  validateattributes(blast, {'char'}, {}, '', 'blast', 4);

  % reg
  validateattributes(reg, {'char'}, {'nonempty'}, '', 'reg', 5);
  [team_id, ext_id, ~, team_type, disp_name, dump_name, pi_name, ~, clr] = cafa_team_register(reg);

  % isdump
  validateattributes(isdump, {'logical'}, {'nonempty'}, '', 'isdump', 6);
  if isdump
    disp_name = dump_name;
  end
  % }}}

  % clean up and filter models {{{
  % 1. remove 'disqualified' models;
  % 2. set aside baseline models;
  % 3. match team names for display.
  % 4. calculate averaged AUC.

  n = numel(aucs);
  qld = cell(1, n); % all qualified models
  bsl = cell(1, 2); % two baseline models
  avg_aucs = zeros(1, n);

  kept = 0;

  % parse model number 1, 2 or 3 from external ID {{{
  % model_num = cell(1, n);
  % for i = 1 : n
  %   splitted_id = strsplit(ext_id{i}, '-');
  %   model_num{i} = splitted_id{2};
  % end
  % }}}

  for i = 1 : n
    index = find(strcmp(team_id, aucs{i}.id));

    if strcmp(aucs{i}.id, naive)
      bsl{1}.auc_mean = nanmean(aucs{i}.auc);
      bsl{1}.auc_q05  = prctile(aucs{i}.auc, 5);
      bsl{1}.auc_q95  = prctile(aucs{i}.auc, 95);
      bsl{1}.auc_std  = nanstd(aucs{i}.auc);
      bsl{1}.auc_ste  = bsl{1}.auc_std / sqrt(sum(~isnan(aucs{i}.auc)));
      bsl{1}.tag      = sprintf('%s', disp_name{index});
      bsl{1}.pi_name  = pi_name{index};
      bsl{1}.color    = (hex2dec(reshape(clr{index}, 3, 2))/255)';
    elseif strcmp(aucs{i}.id, blast)
      bsl{2}.auc_mean = nanmean(aucs{i}.auc);
      bsl{2}.auc_q05  = prctile(aucs{i}.auc, 5);
      bsl{2}.auc_q95  = prctile(aucs{i}.auc, 95);
      bsl{2}.auc_std  = nanstd(aucs{i}.auc);
      bsl{2}.auc_ste  = bsl{2}.auc_std / sqrt(sum(~isnan(aucs{i}.auc)));
      bsl{2}.tag      = sprintf('%s', disp_name{index});
      bsl{2}.pi_name  = pi_name{index};
      bsl{2}.color    = (hex2dec(reshape(clr{index}, 3, 2))/255)';
    elseif strcmp(team_type(index), 'q') % qualified models
      % filtering {{{
      avg_auc = nanmean(aucs{i}.auc);

      % skip models with 'NaN' AUC values
      if isnan(avg_auc)
        continue;
      end

      % skip models with 0 coverage
      if all(aucs{i}.auc(~isnan(aucs{i}.auc)) == 0.5)
        continue;
      end
      % }}}

      % collecting {{{
      kept = kept + 1;
      qld{kept}.mid       = aucs{i}.id; % for temporary useage, will be removed
      qld{kept}.auc_mean  = avg_auc;
      qld{kept}.auc_q05   = prctile(aucs{i}.auc, 5);
      qld{kept}.auc_q95   = prctile(aucs{i}.auc, 95);
      qld{kept}.auc_std  = nanstd(aucs{i}.auc);
      qld{kept}.auc_ste  = bsl{2}.auc_std / sqrt(sum(~isnan(aucs{i}.auc)));

      avg_aucs(kept)      = avg_auc;
      qld{kept}.disp_name = disp_name{index};
      % qld{kept}.tag       = sprintf('%s-%s', disp_name{index}, model_num{index});
      qld{kept}.tag       = sprintf('%s', disp_name{index});
      qld{kept}.pi_name   = pi_name{index};
      qld{kept}.color     = (hex2dec(reshape(clr{index}, 3, 2))/255)';
      % }}}
    else
      % 'x' nop
    end
  end
  qld(kept+1 : end)      = []; % truncate the trailing empty cells
  avg_aucs(kept+1 : end) = [];
  % }}}

  % sort averaged Fmax and pick the top K {{{
  if K == 0
    sel = {};
  else
    % keep find the next team until
    % 1. find K (= 10) models, or
    % 2. exhaust the list
    % Note that we only allow one model selected per PI.

    sel = cell(1, K);
    sel_pi = {};
    [~, index] = sort(avg_aucs, 'descend');
    nsel = 0;
    for i = 1 : numel(qld)
      if ~ismember(qld{index(i)}.pi_name, sel_pi)
        nsel = nsel + 1;
        sel_pi{end + 1} = qld{index(i)}.pi_name;
        sel{nsel} = qld{index(i)};
      end
      if nsel >= K
        break;
      end
    end
    if nsel == 0
      warning('cafa_sel_top_term_auc:NoSel', 'None of the models are selected.');
      sel = [];
    elseif nsel < K
      warning('cafa_sel_top_term_auc:LessThanK', 'Only selected %d models.', nsel);
      sel(nsel + 1 : end) = [];
    end
  end
  % }}}

  % fill-up extra info {{{
  info.all_mid = cell(1, numel(qld));
  for i = 1 : numel(qld)
    info.all_mid{i} = qld{i}.mid;
  end

  info.top_mid = cell(1, numel(sel));
  for i = 1 : numel(sel)
    info.top_mid{i} = sel{i}.mid;
    sel{i} = rmfield(sel{i}, 'mid'); % remove temporary field: mid
  end
  % }}}
return

% -------------
% Yuxiang Jiang (yuxjiang@indiana.edu)
% Department of Computer Science
% Indiana University, Bloomington
% Last modified: Mon 08 May 2017 11:23:50 PM E
