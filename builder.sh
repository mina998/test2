
[ -f './lswp' ] && rm ./lswp
if [ -z "$1" ]; then
    cat ./colors.sh | sed '/^ *#/d' >> lswp
    cat ./defined.sh | sed 's/run_path=\$(pwd)/run_path=\/usr\/local\/bin/' | sed '/^ *#/d' >> lswp
    # cat ./defined.sh | sed '/^ *#/d' >> ols.sh
    cat ./utils.sh | sed '/^ *#/d' >> lswp
    cat ./sitecmd.sh | sed '/^ *#/d' >> lswp
    cat ./main.sh | sed '/source \.\//d' | sed '/^ *#/d' >> lswp

else
    cat ./colors.sh  >> lswp
    cat ./defined.sh | sed 's/run_path=\$(pwd)/run_path=\/usr\/local\/bin/' >> lswp
    cat ./utils.sh >> lswp
    cat ./sitecmd.sh >> lswp
    cat ./main.sh | sed '/source \.\//d' >> lswp
fi
