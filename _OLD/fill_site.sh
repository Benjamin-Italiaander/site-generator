P_art="content/art_i_enjoy"


## MAIN INDEX
curl https://raw.githubusercontent.com/Benjamin-Italiaander/My_Notes/refs/heads/main/README.md > content/_index.md

mkdir -p content/linux



# Clone kitty Readme from github
curl https://raw.githubusercontent.com/Benjamin-Italiaander/kitty_terminal_working_config_example/refs/heads/main/README.md > content/linux/kitty.md

# Clone a small example of the date command in bash


P_art_img="content/img"
mkdir -p "$P_art_img"
#wget -P $P_art_img https://raw.githubusercontent.com/Benjamin-Italiaander/My_Notes/main/slices_of_life/img/wood_block_prints/uchida_woodblock_prints_txt_1.jpg 
git clone git@github.com:Benjamin-Italiaander/My_Notes.git
cp -r My_Notes/slices_of_life/img content 
git -C My_Notes pull


#Clone art_i_enjoy
#curl https://raw.githubusercontent.com/Benjamin-Italiaander/My_Notes/refs/heads/main/slices_of_life/art_i_enjoy/README.md > $P_art/_index.md

curl https://raw.githubusercontent.com/Benjamin-Italiaander/My_Notes/refs/heads/main/slices_of_life/art_i_enjoy/Wood_Block_Printing_Uchinda/README.md > $P_art/woodblock_printing.md

cat  My_Notes/slices_of_life/art_i_enjoy/takamizawa_mokuhansha/README.md > $P_art/takamizawa_mokuhansha.md
cat  My_Notes/slices_of_life/art_i_enjoy/README.md > $P_art/_index.md

cp My_Notes/avatar.png  content

# Books
P_books="content/books"

mkdir -p "$P_books"

cat My_Notes/slices_of_life/my_curated_booklist/README.md > $P_books/_index.md
cat My_Notes/slices_of_life/my_curated_booklist/personal_development.md > $P_books/pd.md
cat My_Notes/slices_of_life/my_curated_booklist/the_power_of_now_Eckhart_Tolle.md > $P_books/tpon.md

cat My_Notes/slices_of_life/my_curated_booklist/toon_tellegen.md > $P_books/toon_tellegen.md

cat My_Notes/slices_of_life/my_curated_booklist/poetry.md > $P_books/poetry.md

cat My_Notes/slices_of_life/my_curated_booklist/relations.md > $P_books/relations.md

cat My_Notes/Linux/README.md > content/linux/_index.md

cat  My_Notes/Linux/benchmark/benchmark_writespeed.md > content/linux/benchmark_write_speed.md


cat My_Notes/Linux/bash_tricks/date_command.md > content/linux/date_command.md

P_ybk="content/yubikey"
mkdir -p "$P_ybk"
cat My_Notes/Linux/yubikey/README.md > $P_ybk/_index.md
cat My_Notes/Linux/yubikey/EN_Install_all_dependencies.md > $P_ybk/EN_Install_all_dependencies.md
cat My_Notes/Linux/yubikey/EN_yubikey_install_ykman.md > $P_ybk/EN_yubikey_install_ykman.md

