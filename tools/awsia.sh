#!/bin/bash


##### CONSTANTS
COMMANDS=(
	assume
	unassume
	get_active
	list_profiles
	get_config
	usage
	open_console
)


##### FUNCTIONS
# display usage
usage(){
	cat <<EOF

#############################################
#         AWS Identity Access Tools         #
#############################################

Helper functions for working with AWS Profiles

usage: <command> [-o|--options option-value]
    commands:
    	assume            assumes specified aws profile
        unassume          unassumes current aws profile
		open_console      opens aws console to aws profile
        get_active        displays active aws profile
        list_profiles     lists available aws profiles
        get_config        displays config of specified profile
        help              prints usage information
EOF
	return 1
}

# Assumes AWS Role based on supplied AWS Profile.

usage_args(){

	cat <<EOF
usage: command [-p|--profile profile-name]
    options
        -p,--profile        name of aws profile to use
        -h,--help           show this usage description
EOF
	return 1
}

display_arg_help(){
	local desc=$1
	shift

	if [[ "$*" == *"-h"* || "$*" == *"--help"* ]]; then
		printf "\n%s\n\n" "$desc"
		usage_args;
		return 1
	fi
	return 0
}

error(){
	printf "ERROR: %s\n" "$1" >&2
	return 1
}

warn(){
	printf "WARN: %s\n" "$1" >&1
	return 1
}

iterate_commands(){
	for command in "${COMMANDS[@]}"; do
		if [[ "$1" == "$command" ]]; then
			$command "$@"
			return 0
		fi
	done
	return 1
}

get_option_value(){
	if [[ -z $1 ]]; then
		return 1
	fi

	local option=$1
	shift

	while :; do
		if [[ $option == *$1* ]]; then
			if [[ -n $2 ]]; then
				echo "$2"
				return 0
			fi
			break
		fi
		shift
	done

	return 1
}

# list available aws profiles
list_profiles(){
	printf "\nAvailable Profiles\n------------------\n"
	aws configure list-profiles
}

# returns current aws profile
get_active(){
	# header "Active AWS Profile"
	printf "\nActive AWS Profile\n------------------\n"
	[[ -z $AWS_PROFILE ]] && warn "no AWS Profile active."
	echo "$AWS_PROFILE"
}

# print profile configuration
get_config(){
	local option="-p|--profile"
	local profile_name=$(get_option_value "$option" "$@")
	local desc="Prints the configuration for the AWS Profile"

	printf "\nProfile Configuration\n---------------------\n"

	! display_arg_help "$desc" "$@" && return 1

	if [[ -z $profile_name ]]; then
		warn "Usage: print requires specified profile name using \"-p|--profile profile-name\" option"
		return 1
	fi

	aws configure list --profile "$profile_name"
}

open_console(){
	if [[ -z $AWS_PROFILE ]]; then
		error "failed to open aws console. call 'assume' first to set an active profile"
		return 1
	fi

	local identity=$(aws sts get-caller-identity)
	local account=$(echo $identity | jq -r '.Account')
	open https://$account.signin.aws.amazon.com/console
}

# assume named aws profile
assume() {
	local option="-p|--profile"
	local profile_name=$(get_option_value "$option" "$@")
	local desc="Assumes the role for the AWS Profile"

	printf "\nAssuming Role\n---------------\n"

	# check for help flag and profile_name
	! display_arg_help "$desc" "$@" && return 1

	if [[ -z $profile_name ]]; then
		warn "Usage: assume requires specified profile name using \"-p|--profile profile-name\" option"
		return 1
	fi

	# aws configure get role_arn --profile $profile_name
	local role_arn=$(aws configure get role_arn --profile "$profile_name")

	if [[ -z $role_arn ]]; then
		error "aws profile must be configured with assuming role. see aws configuration instructions for role arns"
		return 1
	fi

	echo "Assuming Role: $role_arn"

	local session_name="AWSCLI-Session-$profile_name"
	local assumed_role=$(aws sts assume-role --role-arn "$role_arn" --role-session-name "$session_name")

	if [[ -z $assumed_role ]]; then
		error "failed to assume role with profile: $profile_name"
		return 1
	fi

	echo "Successfully set current AWS Profile: $profile_name"

	export AWS_DEFAULT_PROFILE="$profile_name"
  	export AWS_PROFILE="$profile_name"
  	export AWS_EB_PROFILE="$profile_name"
}

unassume(){
	printf "\nUnassuming Role\n---------------\n"
	echo "Clearing Active Profile: $AWS_PROFILE"
    unset AWS_DEFAULT_PROFILE AWS_PROFILE AWS_EB_PROFILE
    unset AWS_ACCESS_KEY_ID AWS_SECRET_ACCESS_KEY AWS_SESSION_TOKEN
	echo "AWS Profile cleared."
}


##### MAIN
if [[ "-h|--help" == *"$1"* || -z $1 ]]; then
	usage;
else
	# iterate commands for input command
	if ! iterate_commands "$@"; then
		# command not found or error returned
		echo; error "Command \"$1\" not found."; usage
	fi
fi