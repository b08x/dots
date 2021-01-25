define :midiarpeggiate do |prog, tonic, mode=:major, pattern=[0, 1, 2, 3], reps=2|
  sc = scale(tonic, mode, num_octaves: 4)
  prog.each do |deg|
    puts "prog", prog
    reps.times do
      with_synth :pluck do
        midi sc[deg-1] - 12, sustain: 0.9, amp: 2
      end
      t = 1.0 / pattern.length
      pattern.each do |i|
        n = sc[deg - 1 + 2*i + (i+1) / 4]
        #puts "n", n
        midi n, sustain: 1.5 * t, amp: 0.8
        sleep t
      end
    end
  end
end

define :arpeggiate do |prog, tonic, mode=:major, pattern=[0, 1, 2, 3], reps=2|
  sc = scale(tonic, mode, num_octaves: 4)
  prog.each do |deg|
    puts "prog", prog
    reps.times do
      with_synth :piano do
        midi sc[deg-1] - 12, sustain: 0.9, amp: 2
      end
      t = 1.0 / pattern.length
      pattern.each do |i|
        n = sc[deg - 1 + 2*i + (i+1) / 4]
        #puts "n", n
        play n, sustain: 1.5 * t, amp: 0.8
        sleep t
      end
    end
  end
end
