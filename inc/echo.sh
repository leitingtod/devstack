function head1 {
    #[ -z "$CECHO_IS_IMPORTED" ]
    cecho -y "* $@"
}

function head2 {
    cecho -p "** $@"
}

function head3 {
    cecho -b "*** $@"
}

function text {
    local green="\e[1;30m"
    local yellow="\e[1;32m"
    local nc="\e[0m"
    if [[ $1 == '-n' ]]; then
        shift 1
        cecho -bk "==" -g -B "$@"
    else
        cecho -bk "==" -g -B "$@" -n
    fi
}

function perror {
    cecho -r $@ -n
}

function prompt {
    local type=$1
    shift
    local org_opt="-bk # -B"
    org_opt=
    case $type in
        hed)
            case $# in
                3)
                    cecho $org_opt -b $1 -g -B $2 -B -b $3;;
                2)
                    cecho $org_opt -b $1 -g -B $2;;
            esac;;
        sel)
            case $# in
                3)
                    cecho $org_opt -b $1 -g -B $2 -B -b $3;;
                2)
                    cecho $org_opt -g $1 -B -b $2;;
            esac;;
        err)
            cecho $org_opt -r $1 -g -B $2 -r $3;;
    esac
}
