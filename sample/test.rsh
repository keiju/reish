# シンプルコマンド
ls
ls -l
ls -l -F
/ls -l


# コンポジット
ls; ls
ls; ls; ls

# 論理コマンド
true
false
true && ls
false || ls

# パイプライン
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

ls *
ls TODO*
ls [a-z]*
#ls ~

# イテレータ
ls | each do |l| p $l end
ls | each{|l| p $l}
ls.each{|l| p $l}
ls::each{|l| p $l}

# グループコマンド
puts (ls)
puts (ls;ls -l)

# xstringコマンド
puts `ls`
puts `ls; ls -l`

#trivial command
$ls
echo $ls
echo $ls(-l)

# literal
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

# アサインコマンド
foo = foo
bar = 100
baz = %[1 2 foo]

# インデックスアサインコマンド
baz[2] = bar

# インデックスレフ
baz[2]
echo $baz[2]

#BEGIN
begin
  ls
  ls -l
end


