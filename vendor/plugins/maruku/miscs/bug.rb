puts [].each do end   # ok (equiv. to "puts nil")
[1].each do end       # ok
puts [1].each do end  # 3:in `each': no block given (LocalJumpError)
