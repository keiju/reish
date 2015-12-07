
echo "シンプルコマンド"
ls
ls -l
ls -l -F
/ls -l

echo "括弧付きシンプルコマンド"
ls(-l)
ls(-l -F)
ls(-l, -F)
/ls(-l)

echo "コンポジット"
ls; ls
ls; ls; ls

echo "論理コマンド"
true
false
true && ls
false || ls

echo "パイプライン"
ls | cat
ls -l | grep %/TODO/
ls -l | /grep TODO

ls.cat
ls(-l).cat
ls(-l).grep(%/TODO/)
ls(-l)./grep(TODO)

ls::cat
ls(-l)::cat
ls(-l)::grep(%/TODO/)
ls(-l)::/grep(TODO)

ls | grep %/TODO/ | cat
ls | /grep TODO | cat

echo "ワイルドカード"
ls *
ls TODO*
ls [a-z]*
#ls ~

echo "イテレータ"
ls | each do |l| p $l end
ls | each{|l| p $l}
ls.each{|l| p $l}
ls::each{|l| p $l}

echo "グループ"
puts (ls)
puts (ls;ls -l)

echo "グループコマンド"
(ls)
(ls;ls -l)
(ls;ls -l) | grep %/R/

echo "xstringコマンド"
puts `ls`
puts `ls; ls -l`

echo "trivial command"
$ls
echo $ls
echo $ls(-l)

echo "literal"
p foo
p "foo"
p %/foo/
p 1000
p $Class
p true
p %[1 2 foo]
p %{foo => bar}
p :foo
p $(1 + 2)

echo "アサインコマンド"
foo = foo
bar = 100
baz = %[1 2 foo]

baz[2] = zoo

echo "インデックスアサインコマンド"
baz[2] = bar

echo "インデックスレフ"
baz[2]
echo $baz[2]

echo "BEGIN..END"
begin
  ls
  ls -l
end


