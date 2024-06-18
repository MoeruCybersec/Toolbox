#! /usr/bin/env bash

# shellcheck disable=SC1091
source "${HOME}/hacking/gadgets/subrecon.env"

run_shuffledns_resolve() {
	shuffledns -d "$domain" -r "$RESOLVERS" -tr "$RESOLVERS_TRUSTED" -mode resolve -silent
}

extract_in_scope_domain() {
	sed '/^.\{2048\}./d' | unfurl -u domains | sed -e 's/^\*\.//' | grep -E "^$domain$\|\.$domain$"
}

################################ Banner ################################

BANNER_SLANT="""
                   __                             
       _______  __/ /_  ________  _________  ____ 
      / ___/ / / / __ \/ ___/ _ \/ ___/ __ \/ __ \\
     (__  ) /_/ / /_/ / /  /  __/ /__/ /_/ / / / /
    /____/\__,_/_.___/_/   \___/\___/\____/_/ /_/ 
                                                  
    > subrecon $*
        
    $(date '+Started on %Y-%m-%d at %H:%M:%S')     ^_^ Good Luck
"""

echo "$BANNER_SLANT"

################################ Utility ################################

function help() {
	echo "Usage:"
	echo
	echo "  subrecon -update-resolvers quick|reliable"
	echo "  subrecon -update-wordlists"
	echo
	echo "  subrecon -enum fast -u domain.com"
	echo "  subrecon -enum norm -l domains.txt"
	echo
	echo "  echo <domain.com> | subrecon -enum deep"
	echo "  subrecon <domains.txt -enum deep"
}

function update_resolvers() {
	# The first argument determines the method to use: 'wget' or 'iresolver'
	local method="$1"

	# Update the resolver if 1 day has passed since the last update and file length is less than 10000
	if [[ ! -f $RESOLVERS ]] || [[ $(find "$RESOLVERS" -mtime +0) ]] || [[ $(wc -l <"$RESOLVERS") -le 10000 ]]; then
		[[ -f $RESOLVERS ]] && rm "$RESOLVERS"

		echo "[+] Update the resolver..."

		if [[ $method == "quick" ]]; then
			wget -q --show-progress -O - "$RESOLVERS_URL" >"$RESOLVERS"
		elif [[ $method == "reliable" ]]; then
			iresolver --target "$RESOLVERS_URL" --threads 2000 --output "$RESOLVERS"
		fi
	fi

	# Update the trusted resolver if 30 days has passed since the last update and file length is less then 10
	if [[ ! -f $RESOLVERS_TRUSTED ]] || [[ $(find "$RESOLVERS" -mtime +29) ]] || [[ $(wc -l <"$RESOLVERS_TRUSTED") -le 10 ]]; then
		[[ -f $RESOLVERS_TRUSTED ]] && rm "$RESOLVERS_TRUSTED"

		echo "[+] Update the trusted resolver..."

		if [[ $method == "quick" ]]; then
			wget -q --show-progress -O - "$RESOLVERS_TRUSTED_URL" >"$RESOLVERS_TRUSTED"
		elif [[ $method == "reliable" ]]; then
			iresolver --target "$RESOLVERS_TRUSTED_URL" --threads 2000 --output "$RESOLVERS_TRUSTED"
		fi
	fi

	echo "[-] $(wc -l "$RESOLVERS")"
	echo "[-] $(wc -l "$RESOLVERS_TRUSTED")"
	echo "[-] The resolvers are up-to-date."

	return
}

function update_wordlists() {
	if [[ ! -s $SUBDOMAINS_TINY ]]; then
		echo "[+] Update the subdomain-tiny wordlists..."
		wget -q --show-progress -O - "$SUBDOMAINS_TINY_URL" >"$SUBDOMAINS_TINY"
	fi

	if [[ ! -s $SUBDOMAINS_MEDIUM ]]; then
		echo "[+] Update the subdomain-medium wordlists..."
		wget -q --show-progress -O - "$SUBDOMAINS_MEDIUM_URL" >"$SUBDOMAINS_MEDIUM"
	fi

	if [[ ! -s $SUBDOMAINS_HUGE ]]; then
		echo "[+] Update the subdomain-huge wordlists..."
		wget -q --show-progress -O - "$SUBDOMAINS_HUGE_URL" >"$SUBDOMAINS_HUGE"
	fi

	if [[ ! -s $SUBDOMAINS_FULL ]]; then
		echo "[+] Update the subdomain-full wordlists..."
		wget -q --show-progress -O - "$SUBDOMAINS_FULL_URL1" "$SUBDOMAINS_FULL_URL2" | sort -u >"$SUBDOMAINS_FULL"
	fi

	if [[ ! -s $PERMUTATIONS ]]; then
		echo "[+] Update the permutation wordlists..."
		wget -q --show-progress -O - "$PERMUTATIONS_URL" >"$PERMUTATIONS"
	fi

	echo "[-] $(wc -l "$SUBDOMAINS_TINY")"
	echo "[-] $(wc -l "$SUBDOMAINS_MEDIUM")"
	echo "[-] $(wc -l "$SUBDOMAINS_HUGE")"
	echo "[-] $(wc -l "$SUBDOMAINS_FULL")"
	echo "[-] $(wc -l "$PERMUTATIONS")"
	echo "[-] The wordlists are up-to-date."

	return
}

function check_network() {
	if [[ $(curl -I -m 10 -o /dev/null -s -w %{http_code} https://www.google.com) != 200 ]]; then
		echo "[!] The network is not connected"
		exit 1
	fi
}

################################ Option #################################

if [[ $# -eq 0 ]] && [[ -t 0 ]]; then
	help
fi

while (("$#")); do
	case $1 in
	-ur | -update-resolvers)
		shift
		case $1 in
		reliable)
			update_resolvers "reliable"
			shift
			;;
		quick)
			update_resolvers "quick"
			shift
			;;
		*)
			echo "Usage: -update-resolvers <quick|reliable>" 1>&2
			exit 1
			;;
		esac
		;;
	-uw | -update-wordlists)
		update_wordlists
		shift
		;;
	-enum | enum)
		shift
		case $1 in
		fast)
			mode=fast
			shift
			;;
		norm)
			mode=norm
			shift
			;;
		deep)
			mode=deep
			shift
			;;
		*)
			echo "Usage: [-enum <fast|norm|deep>]"
			;;
		esac
		;;
	-d | -domain)
		shift
		if [[ $1 ]]; then
			domain=$1
		else
			echo "Usage: [-d <domain.com>]"
			exit 1
		fi
		shift
		;;
	-l | -list)
		shift
		if [[ -s $1 ]]; then
			domain_list=$1
		else
			echo "File $1 is empty"
			exit 1
		fi
		shift
		;;
	*)
		help
		exit 1
		;;
	esac
done

################################# Enum ##################################

function subenum() {

	domain="$1"

	echo "[*] Enumeration: $domain"

	mkdir -p "$domain"

	subenum_bruteforce
	subenum_passive
	subenum_altering
	subenum_airegex
	subenum_noerror
	subenum_scraping
	subenum_dnsenum

	echo "[-] Finished: $(wc -l "$domain"/subdomains_resolved.txt)"
	echo

	if [[ $(wc -l "$domain"/subdomains_resolved.txt) = 0 ]]; then
		echo "$domain" | anew -q domains_main.txt
	else
		rm -rf "$domain"
	fi
}

function subenum_bruteforce() {
	echo "[+] [$(date "+%H:%M:%S")] Starting bruteforce"

	case $mode in
	fast)
		shuffledns -d "$domain" -w "$SUBDOMAINS_TINY" -r "$RESOLVERS" -tr "$RESOLVERS_TRUSTED" -mode bruteforce -silent | anew "$domain/subdomains_resolved.txt"
		;;
	norm)
		shuffledns -d "$domain" -w "$SUBDOMAINS_HUGE" -r "$RESOLVERS" -tr "$RESOLVERS_TRUSTED" -mode bruteforce -silent | anew "$domain/subdomains_resolved.txt"
		;;
	deep)
		shuffledns -d "$domain" -w "$SUBDOMAINS_FULL" -r "$RESOLVERS" -tr "$RESOLVERS_TRUSTED" -mode bruteforce -silent | anew "$domain/subdomains_resolved.txt"
		;;
	esac
}

function subenum_passive() {
	echo "[+] [$(date "+%H:%M:%S")] Starting passive"

	case $mode in
	fast)
		curl -s "https://crt.sh/?q=${domain}&output=json" | jq -r '.[] | .common_name, .name_value' | extract_in_scope_domain | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		bbot -t "$domain" -f subdomain-enum -rf passive -em massdns -y --config "$BBOT_CONFIG" --silent -om json | jq -r 'select(.scope_distance==0) | select(.type=="DNS_NAME") | .data' | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		subfinder -d "$domain" -s fofa,chaos -es github -provider-config "$SUBFINDER_CONFIG" -silent -duc | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		;;
	norm | deep)
		curl -s "https://crt.sh/?q=${domain}&output=json" | jq -r '.[] | .common_name, .name_value' | extract_in_scope_domain | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		bbot -t "$domain" -f subdomain-enum -rf passive -em massdns -y --config "$BBOT_CONFIG" --silent -om json | jq -r 'select(.scope_distance==0) | select(.type=="DNS_NAME") | .data' | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		subfinder -d "$domain" -all -es github -provider-config "$SUBFINDER_CONFIG" -silent -duc | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		amass enum -passive -d "$domain" -timeout 10 -config "$AMASS_CONFIG" -silent | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		;;
	esac
}

function subenum_altering() {
	[[ $mode == "fast" ]] && return 0

	echo "[+] [$(date "+%H:%M:%S")] Starting altering"

	# shellcheck disable=SC2094
	case $mode in
	norm)
		if [[ -s "$domain/subdomains_resolved.txt" ]] && [[ $(wc -l <subdomains_resolved.txt) -le 500 ]]; then
			alterx -enrich -silent -duc <subdomains_resolved.txt | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
			alterx -enrich -silent -duc <subdomains_resolved.txt | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		fi
		;;
	deep)
		alterx -enrich -silent -duc <subdomains_resolved.txt | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		alterx -enrich -silent -duc <subdomains_resolved.txt | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		;;
	esac
}

function subenum_airegex() {
	[[ $mode == "fast" ]] && return 0

	echo "[+] [$(date "+%H:%M:%S")] Starting airegex"

	# shellcheck disable=SC2094
	case $mode in
	norm)
		if [[ -s "$domain/subdomains_resolved.txt" ]] && [[ $(wc -l <subdomains_resolved.txt) -le 500 ]]; then
			alterx -enrich -silent -duc <subdomains_resolved.txt | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
			alterx -enrich -silent -duc <subdomains_resolved.txt | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		else
			echo "[!] Existing subdomains greater than 500, skip execution"
		fi
		;;
	deep)
		alterx -enrich -silent -duc <subdomains_resolved.txt | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		alterx -enrich -silent -duc <subdomains_resolved.txt | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		;;
	esac
}

function subenum_noerror() {
	[[ $mode == "fast" ]] && return 0

	echo "[+] [$(date "+%H:%M:%S")] Starting noerror"

	if [[ $(echo "absolutely.positively.impossible.$domain" | dnsx -r "$RESOLVERS" -rcode noerror,nxdomain -retry 3 -silent | cut -d ' ' -f 2) == "[NXDOMAIN]" ]]; then
		case $mode in
		norm)
			dnsx -rcode noerror -silent <subdomains_unresolved.txt | cut -d ' ' -f 1 | anew subdomains_noerror.txt
			dnsx -d "$domain" -w "$SUBDOMAINS_MEDIUM" -r "$RESOLVERS" -rcode noerror -silent | cut -d ' ' -f 1 | anew subdomains_noerror.txt
			;;
		deep)
			dnsx -rcode noerror -silent <subdomains_unresolved.txt | cut -d ' ' -f 1 | anew subdomains_noerror.txt
			dnsx -d "$domain" -w "$SUBDOMAINS_FULL" -r "$RESOLVERS" -rcode noerror -silent | cut -d ' ' -f 1 | anew subdomains_noerror.txt
			;;
		esac
	else
		echo "[-] Wildcard detected, skipping noerror Enum"
	fi
}

function subenum_scraping() {
	[[ $mode == "fast" ]] && return 0

	echo "[+] [$(date "+%H:%M:%S")] Starting scraping"

	tmp_websites=$(mktemp)
	trap 'rm -rf "$tmp_websites"' EXIT

	httpx -silent <"${domain}/subdomains_resolved.txt" | anew -q "$tmp_websites"

	tmp_google_analytics_id=$(mktemp)
	trap 'rm -rf "$tmp_google_analytics_id"' EXIT

	nuclei -t ~/ipocs -id google-analytics-id-detection -silent <"$tmp_websites" | cut -d '"' -f 2 | anew -q "$tmp_google_analytics_id"
	while read -r id; do
		udon -s "$id" -silent | extract_in_scope_domain | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
	done <"$tmp_google_analytics_id"

	while read -r website; do
		analyticsrelationships -u "$website" -ch | extract_in_scope_domain | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
	done <"$tmp_websites"

	case $mode in
	norm)
		httpx -tls-grab -json -silent <"$tmp_websites" | jq -r 'try .tls.subject_cn, try .tls.subject_an[], try .csp.domains[]' | extract_in_scope_domain | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		katana -js-crawl -depth 2 -silent <"$tmp_websites" | extract_in_scope_domain | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		;;
	deep)
		httpx -tls-grab -tls-probe -csp-probe -tls-grab -json -silent <"$tmp_websites" | jq -r 'try .tls.subject_cn, try .tls.subject_an[], try .csp.domains[]' | extract_in_scope_domain | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		katana -js-crawl -depth 3 -known-files all -silent | extract_in_scope_domain | anew "${domain}/subdomains_unresolved.txt" | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		;;
	esac
}

function subenum_dnsenum() {
	[[ $mode == "fast" ]] && return 0

	echo "[+] [$(date "+%H:%M:%S")] Starting dnsenum"

	case $mode in
	norm | deep)
		tmp_dnsrecord=$(mktemp)
		trap 'rm -rf "$tmp_dnsrecord"' EXIT
		dnsx -recon -json -silent -l "$domain/subdomains_resolved.txt" >"$tmp_dnsrecord"
		jq -r 'try .a[], try .aaaa[], try .cname[], try .ns[], try .ptr[], try .mx[], try .soa[].name, try .soa[].ns, try .soa[].mailbox' <"$tmp_dnsrecord" | extract_in_scope_domain | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		jq -r 'try .a[]' <"$tmp_dnsrecord" | sort -u | hakip2host | cut -d ' ' -f 3 | extract_in_scope_domain | run_shuffledns_resolve | anew "${domain}/subdomains_resolved.txt"
		;;
	esac
}

################################# Run #################################

# STDIN input
if [[ ! -t 0 ]]; then
	if [[ ! $mode ]]; then
		echo "[!] Please specify a mode [-enum <fast|norm|deep>]"
		exit 1
	fi
	while IFS= read -r domain; do
		subenum "$domain"
	done
fi

# -domain flag
if [[ $domain ]]; then
	if [[ ! $mode ]]; then
		echo "[!] Please specify a mode [-enum <fast|norm|deep>]"
		exit 1
	fi
	subenum "$domain"
fi

# -list flag
if [[ $domain_list ]]; then
	if [[ ! $mode ]]; then
		echo "[!] Please specify a mode [-enum <fast|norm|deep>]"
		exit 1
	fi
	while IFS= read -r domain; do
		subenum "$domain"
	done <"$domain_list"
fi

if [[ $mode ]]; then
	if [[ ! $domain ]] || [[ ! $domain_list ]] || [[ -t 0 ]]; then
		echo "[!] Please specify a target or target file [-d <domain.com>] [-l domains.txt]"
	fi
fi
