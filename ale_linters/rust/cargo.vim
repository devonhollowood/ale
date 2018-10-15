" Author: Daniel Schemala <istjanichtzufassen@gmail.com>,
" Ivan Petkov <ivanppetkov@gmail.com>,
" Devon Hollowood <devonhollowood@gmail.com>
" Description: rustc invoked by cargo for rust files

call ale#Set('rust_cargo_use_check', 1)
call ale#Set('rust_cargo_use_clippy', 1)
call ale#Set('rust_cargo_check_all_targets', 0)
call ale#Set('rust_cargo_check_examples', 0)
call ale#Set('rust_cargo_check_tests', 0)
call ale#Set('rust_cargo_avoid_whole_workspace', 1)
call ale#Set('rust_cargo_default_feature_behavior', 'default')
call ale#Set('rust_cargo_include_features', '')

function! ale_linters#rust#cargo#GetCargoExecutable(bufnr) abort
    if ale#path#FindNearestFile(a:bufnr, 'Cargo.toml') isnot# ''
        return 'cargo'
    else
        " if there is no Cargo.toml file, we don't use cargo even if it exists,
        " so we return '', because executable('') apparently always fails
        return ''
    endif
endfunction

function! ale_linters#rust#cargo#VersionCheck(buffer) abort
    return !ale#semver#HasVersion('cargo')
    \   ? 'cargo --version'
    \   : ''
endfunction

function! ale_linters#rust#cargo#GetCommand(buffer, version_output) abort
    let l:version = ale#semver#GetVersion('cargo', a:version_output)
    let l:clippy_version = ale#semver#GetVersion('cargo-clippy',
    \   systemlist('cargo clippy -V'))

    let l:use_check = ale#Var(a:buffer, 'rust_cargo_use_check')
    \   && ale#semver#GTE(l:version, [0, 17, 0])
    let l:use_clippy = ale#Var(a:buffer, 'rust_cargo_use_clippy')
    \   && ale#semver#GTE(l:clippy_version, [0, 0, 1])
    let l:use_all_targets = l:use_check
    \   && ale#Var(a:buffer, 'rust_cargo_check_all_targets')
    \   && ale#semver#GTE(l:version, [0, 22, 0])
    let l:use_examples = l:use_check
    \   && ale#Var(a:buffer, 'rust_cargo_check_examples')
    \   && ale#semver#GTE(l:version, [0, 22, 0])
    let l:use_tests = l:use_check
    \   && ale#Var(a:buffer, 'rust_cargo_check_tests')
    \   && ale#semver#GTE(l:version, [0, 22, 0])

    let l:include_features = ale#Var(a:buffer, 'rust_cargo_include_features')

    if !empty(l:include_features)
        let l:include_features = ' --features ' . ale#Escape(l:include_features)
    endif

    let l:avoid_whole_workspace = ale#Var(a:buffer, 'rust_cargo_avoid_whole_workspace')
    let l:nearest_cargo_prefix = ''

    if l:avoid_whole_workspace
        let l:nearest_cargo = ale#path#FindNearestFile(a:buffer, 'Cargo.toml')
        let l:nearest_cargo_dir = fnamemodify(l:nearest_cargo, ':h')

        if l:nearest_cargo_dir isnot# '.'
            let l:nearest_cargo_prefix = 'cd '. ale#Escape(l:nearest_cargo_dir) .' && '
        endif
    endif

    let l:default_feature_behavior = ale#Var(a:buffer, 'rust_cargo_default_feature_behavior')

    if l:default_feature_behavior is# 'all'
        let l:include_features = ''
        let l:default_feature = ' --all-features'
    elseif l:default_feature_behavior is# 'none'
        let l:default_feature = ' --no-default-features'
    else
        let l:default_feature = ''
    endif

    return l:nearest_cargo_prefix . 'cargo '
    \   . (l:use_clippy ? 'clippy' : (l:use_check ? 'check' : 'build'))
    \   . (l:use_all_targets ? ' --all-targets' : '')
    \   . (l:use_examples ? ' --examples' : '')
    \   . (l:use_tests ? ' --tests' : '')
    \   . ' --frozen --message-format=json -q'
    \   . l:default_feature
    \   . l:include_features
endfunction

call ale#linter#Define('rust', {
\   'name': 'cargo',
\   'executable_callback': 'ale_linters#rust#cargo#GetCargoExecutable',
\   'command_chain': [
\       {'callback': 'ale_linters#rust#cargo#VersionCheck'},
\       {'callback': 'ale_linters#rust#cargo#GetCommand'},
\   ],
\   'callback': 'ale#handlers#rust#HandleRustErrors',
\   'output_stream': 'both',
\   'lint_file': 1,
\})
