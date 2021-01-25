# https://github.com/samaaron/sonic-pi/issues/1691
# https://in-thread.sonic-pi.net/t/midi-chords-creation-from-an-external-synth/355/2?u=b08x
# Use: midi_chord chord(:c4,:major), sustain:0.2

define :midi_chord do |notes, *args|
  notes.each do |note|
    print note
    midi note, *args
  end
end
