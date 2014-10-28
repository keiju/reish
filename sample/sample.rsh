p $ARGV

if == $ARGV[1] 1
    echo 1
else
    echo 2
end

begin
  ls
  ls
end

begin
  echo foo
  raise 
rescue 
  ls
end
