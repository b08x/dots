# tty-font Cheatsheet

**Library ID**: `/piotrmurach/tty-font`

## Targeted Usage Examples (GenAI / NLP / Systems)

### Basic Banner Creation with TTY::Font

Source: https://context7.com/piotrmurach/tty-font/llms.txt

Demonstrates how to create banners with different fonts and apply colors using the TTY::Font and Pastel gems. Initializes a font, writes text, and colors the output.

```ruby
require 'tty-font'
require 'pastel'

pastel = Pastel.new

# Yellow DOOM banner
font = TTY::Font.new(:doom)
puts pastel.yellow(font.write("DOOM"))

# Red Star Wars style banner
font = TTY::Font.new(:starwars)
puts pastel.red(font.write("STAR WARS"))

# Green standard banner
font = TTY::Font.new(:standard)
puts pastel.green(font.write("SUCCESS"))

# Bold cyan banner
font = TTY::Font.new(:block)
puts pastel.cyan.bold(font.write("HELLO"))

# Multi-color effect (line by line)
font = TTY::Font.new(:doom)
output = font.write("RUBY")
colors = [:red, :yellow, :green, :cyan, :blue, :magenta]
output.lines.each_with_index do |line, i|
  puts pastel.decorate(line, colors[i % colors.length])
end
```

--------------------------------

### Render Text as ASCII Art with TTY::Font

Source: https://context7.com/piotrmurach/tty-font/llms.txt

Shows how to use the `#write` method to convert strings into multi-line ASCII art. This method supports various characters and allows overriding letter spacing. Examples include rendering basic text, numbers, and text with spaces.

```ruby
require 'tty-font'

# Basic text rendering with standard font
font = TTY::Font.new(:standard)
puts font.write("Hello")
# Output:
#  _   _          _   _ 
# | | | |   ___  | | | |   ___ 
# | |_| |  / _ \ | | | |  / _ \
# |  _  | |  __/ | | | | | (_) |
# |_| |_|  \___| |_| |_|  \___/ 

# Rendering with doom font
doom = TTY::Font.new(:doom)
puts doom.write("DOOM")
# Output:
# ______  _____  _____ ___  ___ 
# |  _  \|  _  ||  _  ||  \/  |
# | | | || | | || | | || .  . |
# | | | || | | || | | || |\/| |
# | |/ / \ \_/ /\ \_/ /| |  | |
# |___/   \___/  \___/ \_|  |_/ 

# Rendering numbers
font = TTY::Font.new(:standard)
puts font.write("12345")
# Output:
#   _   ____    _____   _  _     ____ 
#  / | |___ \  |___ /  | || |   | ___|
#  | |   __) |   |_ \  | || |_  |___ \ 
#  | |  / __/   ___) | |__   _|  ___) |
#  |_| |_____| |____/     |_|   |____/ 

# Rendering with custom letter spacing
font = TTY::Font.new(:doom)
puts font.write("DOOM", letter_spacing: 4)
# Output:
# ______      _____      _____     ___  ___ 
# |  _  \    |  _  |    |  _  |    |  \/  |
# | | | |    | | | |    | | | |    | .  . |
# | | | |    | | | |    | | | |    | |\/| |
# | |/ /     \ \_/ /    \ \_/ /    | |  | |
# |___/       \___/      \___/     \_|  |_/ 

# Rendering with spaces in text
font = TTY::Font.new(:standard)
puts font.write("a b c")
# Output:
#            _ 
#    __ _   | |__       ___ 
#   / _` |  | '_ \     / __|
#  | (_| |  | |_) |   | (__ 
#   \__,_|  |_.__/     \___| 

# Rendering special characters
font = TTY::Font.new(:standard)
puts font.write("*+-.")
# Output:
# 
#  __\/\__    _ 
#  \    /  _| |_       _ 
#  /_  _\ |_   _|  _   (_) 
#    \/     |_|   ( ) 
#                 |/ 

```

--------------------------------

### TTY::Font Available Fonts Reference

Source: https://context7.com/piotrmurach/tty-font/llms.txt

Provides examples of various available fonts in TTY::Font, including 'standard', 'doom', 'starwars', '3d', 'block', and 'straight'. Shows the rendered output for each font.

```ruby
require 'tty-font'

# Standard font - Clean, readable (height: 6 lines)
puts TTY::Font.new(:standard).write("ABC")
#      _      ____     ____
#     / \    | __ )   / ___|
#    / _ \   |  _ \  | |
#   / ___ \  | |_) | | |___
#  /_/   \_\ |____/   \____|

# Doom font - Bold, game-inspired (height: 8 lines)
puts TTY::Font.new(:doom).write("ABC")
#   ___  ______  _____
#  / _ \ | ___ \/  __ \
# / /_\ \| |_/ /| /  \/
# |  _  || ___ \| |
# | | | || |_/ /| \__/\
# \_| |_/\____/  \____/

# Star Wars font - Iconic movie style (height: 6 lines)
puts TTY::Font.new(:starwars).write("ABC")
#      ___      .______     ______
#     /   \     |   _  \   /      |
#    /  ^  \    |  |_)  | |  ,----'
#   /  /_  \   |   _  <  |  |
#  /  _____  \  |  |_)  | |  `----.
# /__/     \__\ |______/   \______| 

# 3D font - Dimensional effect (height: 6-8 lines)
puts TTY::Font.new(:3d).write("ABC")
#  ______  ____     ____
# /\  _  \/\  _`\  /\  _`\
# \ \ \_\ \ \ \_\ \ \ \/\_\
#  \ \  __ \ \  _ <'\ \ \/_/_
#   \ \ \/\ \ \ \_\ \ \ \_\ \
#    \ \_\ \_\ \____/ \ \____/
#     \/_/\/_/\___/   \___/

# Block font - Solid, heavy (height: 7 lines)
puts TTY::Font.new(:block).write("ABC")
#   _|_|    _|_|_|      _|_|_|
# _|    _|  _|    _|  _|
# _|_|_|_|  _|_|_|    _|
# _|    _|  _|    _|  _|
# _|    _|  _|_|_|      _|_|_|

# Straight font - Minimal, compact (height: 3-4 lines)
puts TTY::Font.new(:straight).write("ABC")
#      __ __
#  /\ |__)/ 
# /--\|__)\__
```

### Summary

Source: https://context7.com/piotrmurach/tty-font/llms.txt

TTY::Font is an essential component for Ruby developers building command-line interfaces who want to add visual impact through ASCII art text rendering. The gem excels at creating eye-catching banners, headers, and splash screens with minimal code. Its straightforward API requires just two method calls - initialization with a font choice and the `write` method to render text - making integration trivial for any terminal application. The library integrates naturally with other TTY toolkit components and the broader Ruby ecosystem, particularly the Pastel gem for colorized output. Common use cases include CLI tool welcome screens, section headers in terminal UIs, game titles, and attention-grabbing warning or success messages. For developers building terminal applications with tools like Thor, TTY-Prompt, or custom CLI frameworks, TTY::Font provides a polished way to enhance user experience without complex dependencies or configuration.

--------------------------------

### TTY::Font > Usage

Source: https://github.com/piotrmurach/tty-font/blob/master/README.md

To adjust the spacing between all the letters in a piece of text use `:letter_spacing` option:

```ruby
puts font.write("DOOM", letter_spacing: 4)
# =>
# ______      _____      _____     ___  ___
# |  _  \    |  _  |    |  _  |    |  \/  |
# | | | |    | | | |    | | | |    | .  . |
# | | | |    | | | |    | | | |
# | |/ /     \ \_/ /    \ \_/ /    | |  | |
# |___/       \___/      \___/     \_|  |_/
```

If you wish to print text in color use [pastel](https://github.com/piotrmurach/pastel):

```ruby
pastel = Pastel.new
puts pastel.yellow(font.write("DOOM"))
```

---

*Generated by RubyGemDB Explorer for tty-font*
