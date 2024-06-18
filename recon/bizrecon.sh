#! /usr/bin/env bash

bizrecon() {

  mode=$1
  search=$2

  encyclopedia_search_urls=(
    "https://zh.wikipedia.org/w/index.php?search=%search"
    "https://en.wikipedia.org/w/index.php?search=%search"
    "https://www.baike.com/search?keyword=%search&activeTab=DOC_TAB"
    "https://baike.baidu.com/search?word=%search"
    "https://wiki.mbalib.com/wiki/Special:Search?search=%search"
  )

  company_search_urls=(
    "https://shuidi.cn/pc-search?key=%search"
    "https://www.qcc.com/web/search?key=%search"
    "https://www.tianyancha.com/search?key=%search"
    "https://aiqicha.baidu.com/s?q=%search"
    "https://sou.xiaolanben.com/search?key=%search"
    "https://www.qixin.com/search?key=%search"
    "https://www.qichamao.com/search/all/%search"
  )

  application_search_urls=(
    "https://app.diandian.com/search/all-24-%search"
    "https://app.diandian.com/search/all-75-%search"
    "https://sou.xiaolanben.com/search?key=%search"
    "https://www.qimai.cn/search/index/country/cn/version/ios14/search/%search"
    "https://www.qimai.cn/search/android/market/6/search/%search"
    "https://www.taptap.cn/search/%search"
    "https://www.google.com/search?q=site:apps.apple.com+(\"Mac+App+Store+上的\"|\"on+the+Mac+App+Store\")+%search"
    "https://www.google.com/search?q=site:apps.microsoft.com+%search"
  )

  domainname_search_urls=(
    "https://www.qcc.com/web_net?searchKey=%search" # 企查查
    https://beian.tianyancha.com/search/%search # 天眼查
    "https://aiqicha.baidu.com/icpsearch" # 爱企查
    "https://icplishi.com/%search/" # IP 历史
    "https://icp.chinaz.com/%search" # ChinaZ
    "https://www.beianx.cn/search/%search" # 备案查询网
  )

  miscellaneous_search_urls=(
    "https://www.baidu.com/s?wd=%search"
    "https://www.so.com/s?q=%search"
    "https://so.toutiao.com/search?dvpf=pc&keyword=%search"
    "https://www.google.com/search?q=%search"
    "https://www.bing.com/search?q=%search"
    "https://duckduckgo.com/?q=%search"
    "https://yandex.com/search/?text=%search"
    "https://search.yahoo.com/search?p=%search"
    "https://www.mbalib.com/s?q=%search"
    "https://www.sogou.com/web?query=%search"
    "https://weixin.sogou.com/weixin?type=1&query=%search"
    "https://weixin.sogou.com/weixin?type=2&query=%search"
    "https://www.gitlogs.com/most_popular?topic=%search"
  )

  case $mode in
  "wiki")
    urls=("${encyclopedia_search_urls[@]}")
    ;;
  "company")
    urls=("${company_search_urls[@]}")
    ;;
  "app")
    urls=("${application_search_urls[@]}")
    ;;
  "domain")
    urls=("${domainname_search_urls[@]}")
    ;;
  "misc")
    urls=("${miscellaneous_search_urls[@]}")
    ;;
  "all")
    urls=("${encyclopedia_search_urls[@]}" "${company_search_urls[@]}" "${application_search_urls[@]}" "${domainname_search_urls[@]}" "${miscellaneous_search_urls[@]}")
    ;;
  *)
    echo "Usage: bizrecon.sh [wiki|company|app|domain|misc|all] search_term"
    return 1
    ;;
  esac

  for url in "${urls[@]}"; do
    echo "${url//%search/$search}"
  done
}

if [ $# -ne 2 ]; then
  echo "Usage: bizrecon.sh [wiki|company|app|domain|misc|all] search_term"
  exit 1
fi

bizrecon "$1" "$2"
