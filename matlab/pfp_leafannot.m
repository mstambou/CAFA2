function [annotation] = pfp_leafannot(oa)
%PFP_LEAFANNOT Leaf annotation
% {{{
%
% [annotation] = PFP_LEAFANNOT(oa);
%
%   Returns the annotation matrix only having leaf annoation bits.
%
% Input
% -----
% [struct]
% oa:         The ontology annotation structure.
%
% Output
% ------
% [logical and sparse]
% annotation: The annoation matrix.
%
% Dependency
% ----------
%[>]pfp_oabuild.m
%[>]Bioinformatics Toolbox:graphtopoorder
% }}}

  % check inputs {{{
  if nargin ~= 1
    error('pfp_leafannot:InputCount', 'Expected 1 input.');
  end

  % check the 1st input 'oa' {{{
  validateattributes(oa, {'struct'}, {'nonempty'}, '', 'oa', 1);
  % }}}
  % }}}

  % calculation {{{
  n = numel(oa.object);
  m = numel(oa.ontology.term);

  % find a topological order, from root to leaf
  order = graphtopoorder(oa.ontology.DAG');
  has_annot = any(oa.annotation, 1);

  annotation = oa.annotation;
  for i = 1 : numel(order)
    t = order(i);
    if ~has_annot(t)
      continue;
    end

    % find child
    c = oa.ontology.DAG(:, t) ~= 0;

    % clear current annotation if any of the child has annotation
    annotation(any(annotation(:, c), 2), t) = false;
  end
  % }}}
return

% -------------
% Yuxiang Jiang (yuxjiang@indiana.edu)
% Department of Computer Science
% Indiana University Bloomington
% Last modified: Fri 26 Feb 2016 08:44:27 PM E
