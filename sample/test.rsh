
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

begin
  ls
  ls -l
ensure
  echo "ENSURE"
end

begin
  ls
  raise "raise"
  ls -l
rescue
  echo "CATCH RAISE"
ensure
  echo "ENSURE"
end


begin
  ls
  raise "raise"
  ls -l
rescue $Interrupt
  echo "CATCH RAISE1"

rescue
  echo "CATCH RAISE2"

ensure
  echo "ENSURE"
end

begin
  ls
  raise "raise"
  ls -l
rescue $Interrupt
  echo "CATCH RAISE1"

rescue
  echo "CATCH RAISE2"

else
  echo "CATCH RAISE3"

ensure
  echo "ENSURE"
end

echo "BREAK 非対応"
echo "NEXT 非対応"
echo "RETRY 非対応"
echo "RETURN 非対応"
echo "REDO 非対応"

echo "IF"
if -e /tmp
  echo "TRUE"
  echo "TRUE"
else
  echo "FALSE"
end

if true
  echo "IF1"
elsif true
  echo "IF2"
end

if true
  echo "IF1"
elsif true
  echo "IF2"
else
  echo "IF3"
end


if true
  echo "IF1"
elsif true
  echo "IF2"
elsif true
  echo "IF3"
else
  echo "IF4"
end

echo "WHILE"
ary=%[1 2 3]
while e = $ary.shift
  echo $e
end

echo "UNTIL"
ary=%[1 2 3]
until (e = $ary.shift).nil?
  echo $e
end

echo "FOR"
for e in %[1 2 3]
  echo $e
end

echo "CASE"
a = true
case $a
when true
  echo "P1"
end

a = true
case $a
when false
  echo "P1"
when true
  echo "P2"
end

a = true
case $a
when false
  echo "P1"
when false
  echo "P2"
else
  echo "P3"
end

echo "FOR"
for e in %[1 2 3]
  echo $e
end

for e in %[1 2 3]
  echo $e
  echo $e
end



