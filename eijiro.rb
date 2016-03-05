# Tested on Eijiro 144.1 & OS X 10.11 with Auxiliary Tools
# (C) 2016 Takayuki Okazaki
# MIT License

# Specification of text file.
# @see: http://www.eijiro.jp/spec.htm

require 'uri'
require 'digest'
require 'optparse'
require 'sqlite3'

class Word
  def initialize(word)
    @word = word
  end

  def id
    identifier(@word)
  end

  def identifier(word)
    Digest::SHA256.hexdigest word
  end
end

class WordChunk < Word
  def initialize(defs)
    super(defs[0].word)
    @defs = defs

    # require render_words to parse attrs.
    @attrs = defs.map do |d|
      d.attrs
    end.reduce do |x, y|
      x.merge y
    end
    @rendered = render_entries
  end

  def conjugation_entries
    @defs.map do |d|
      d.conjugation_entries
    end.join('')
  end

  def entries_with_priority
    wk = WordKlass.new
    @defs.select do |d|
      not d.rendered.empty?
    end.map do |d|
      klass_desc = wk.parse_label(d.klass)
      klass_prio = wk.priority(klass_desc)

      {
          :prio => klass_prio,
          :desc => klass_desc,
          :word => d
      }
    end.map do |d|
      {
          d[:desc][:major] => d
      }
    end.reduce({}) do |x, y|
      y.each do |k, v|
        (x[k] ||= []) << v
      end
      x
    end
  end

  def render_wordclass(klass_label)
    if klass_label.empty?
      ''
    else
      "<span class='wordclass'>#{klass_label}</span><br/>"
    end
  end

  def render_entries
    entries = entries_with_priority
    entries.keys.sort.map do |k|
      klass_label = entries[k][0][:desc][:label]
      klass_head  = render_wordclass(klass_label)
      if klass_head.strip.empty?
        klass_item_head = '<p>'
        klass_item_tail = '</p>'
        klass_tail      = ''
      else
        klass_head      = klass_head + '<ol>'
        klass_item_head = '<li>'
        klass_item_tail = '</li>'
        klass_tail      = '</ol>'
      end

      klass_head +
        entries[k].sort_by do |e|
          e[:prio]
        end.map do |e|
          klass_item_head + e[:word].render_body + klass_item_tail
        end.join('') + 
        klass_tail

    end.join('')
  end

  def render_attr(klass, value)
    "<span class='attr'><span class='#{klass}'>#{value}</span></span>"
  end

  def render_attr_pronounce(value)
    "<span class='pr'>#{value}</span>"
  end

  def render_attr_pronounce_attn(value)
    "<span class='pr'><span class='attention'>!</span> #{value}</span>"
  end

  def render_attr_level(value)
    render_attr('level', value)
  end

  def render_attr_kana(value)
    render_attr('kana', value)
  end

  def render_attr_part(value)
    render_attr('part', value)
  end

  def render_attr_conj(value)
    render_attr('conj', value)
  end

  def render_part_pronounce
    pronounce_attrs = [:pronounce, :pronounce_attn]
    @attrs.select do |k, v|
      pronounce_attrs.include?(k)
    end.map do |k, v|
      method("render_attr_#{k}".to_sym).call(v)
    end.join('')
  end

  def render_part_sub_attrs
#    sub_attrs = [:level, :kana, :conj, :part]
    sub_attrs = [:level, :conj, :part]
    attrs_body = @attrs.select do |k, v|
      sub_attrs.include?(k)
    end.map do |k, v|
      method("render_attr_#{k}".to_sym).call(v)
    end.join('')

    if attrs_body.size > 0
      "<p class='attr'>#{attrs_body}</p>"
    else
      ''
    end
  end

  def render_chunk
    <<ENTRY
<d:entry id='#{id}' d:title=#{@word.encode(:xml => :attr)}>
<d:index d:value=#{@word.encode(:xml => :attr)}/>#{conjugation_entries}
<h1>#{@word.encode(:xml => :text)}#{render_part_pronounce}</h1>
#{render_part_sub_attrs}#{@rendered}
</d:entry>
ENTRY
  end
end

class WordKlass
  def initialize
    @known_klasses = {
        '名' => {
            :label => '名詞',
            :priority => 1
        },
        '代' => {
            :label => '代名詞',
            :priority => 2
        },
        '形' => {
            :label => '形容詞',
            :priority => 3
        },
        '動' => {
            :label => '動詞',
            :priority => 4
        },
        '他動' => {
            :label => '他動詞',
            :priority => 5
        },
        '自動' => {
            :label => '自動詞',
            :priority => 6
        },
        '助' => {
            :label => '助動詞',
            :priority => 7
        },
        '句動' => {
            :label => '句動詞',
            :priority => 8
        },
        '副' => {
            :label => '副詞',
            :priority => 9
        },
        '接' => {
            :label => '接続詞',
            :priority => 10
        },
        '間' => {
            :label => '間投詞',
            :priority => 11
        },
        '前' => {
            :label => '前置詞',
            :priority => 12
        },
        '略' => {
            :label => '略語',
            :priority => 13
        },
        '組織' => {
            :label => '組織名（会社名、団体名など）',
            :priority => 14
        }
    }
  end

  def expand_label(klass)
    if @known_klasses.has_key?(klass)
      @known_klasses[klass][:label]
    else
      klass
    end
  end

  def klass_major_priority(klass)
    if @known_klasses.has_key?(klass)
      sprintf '%04d', @known_klasses[klass][:priority]
    else
      "ZZZ#{klass}"
    end
  end

  def priority(klass_desc)
    "#{klass_desc[:major]}-#{klass_desc[:minor]}"
  end

  def parse_label(klass)
    if klass.match(/(\d+)-([^\d]+)-(\d+)/)
      {
          :klass => $2,
          :label => expand_label($2),
          :major => klass_major_priority($2),
          :minor => sprintf('%04d-%04d', $1, $3)
      }
    elsif klass.match(/(\d+)-([^\d]+)/)
      {
          :klass => $2,
          :label => expand_label($2),
          :major => klass_major_priority($2),
          :minor => sprintf('%04d', $1)
      }
    elsif klass.match(/([^\d]+)-(\d+)/)
      {
          :klass => $1,
          :label => expand_label($1),
          :major => klass_major_priority($1),
          :minor => sprintf('%04d', $2)
      }
    else
      {
          :klass => klass,
          :label => expand_label(klass),
          :major => klass_major_priority(klass),
          :minor => '0000'
      }
    end
  end
end

class WordDefinition < Word
  attr_reader :word, :klass, :conjugations, :desc, :attrs, :rendered

  def self.parse_left(left)
    if left.match(/(.+)\{(.+)\}/)
      {
          :word => $1.strip,
          :klass => $2
      }
    else
      {
          :word => left.strip,
          :klass => ''
      }
    end
  end

  def self.parse_right_conjugation(right)
    if right.match(/【変化】([^【■]+)/)
      $1.gsub(/《.+?》/, '').split(/[^a-zA-Z\(\)]+/).map do |c|
        if c.match(/\(.+?\)/)
          [c.gsub(/[\(\)]/, ''), c.gsub(/\(.+?\)/, '')]
        else
          c
        end
      end.flatten
    else
      []
    end
  end

  def self.parse_right(right)
    {
        :desc => right,
        :conjugations => self.parse_right_conjugation(right)
    }
  end

  def self.parse_line(line)
    if line.match(/^■(.+)\s:\s(.+)/)
      self.parse_left($1).merge(self.parse_right($2))
    else
      raise 'No definition on the line'
    end
  end

  def self.from_line(line)
    self.new(self.parse_line(line.chomp))
  end

  def self.from_row(row)
    self.new(
        {
            :word => row[0],
            :klass => row[1],
            :desc => row[2],
            :conjugations => self.parse_right_conjugation(row[2])
        }
    )
  end

  def self.insert_statement(db)
    db.prepare('INSERT INTO text VALUES (:row, :hash, :word, :klass, :desc)') do |stmt|
      yield stmt
    end
  end

  def self.select_statement(db)
    db.prepare('SELECT word, klass, desc FROM text WHERE hash = :hash') do |stmt|
      yield stmt
    end
  end

  def serialize(stmt, line)
    stmt.execute 'row' => Digest::SHA256.hexdigest(line),
                 'hash' => id,
                 'word' => @word,
                 'klass' => @klass,
                 'desc' => @desc
  end

  def initialize(data)
    super(data[:word])
    @klass = data[:klass]
    @conjugations = data[:conjugations]
    @desc = data[:desc]
    @attrs = {}
    @rendered = render_entry
  end

  def conjugation_entries
    @conjugations.map do |c|
      title = "#{c} (#{@word})"
      "<d:index d:value=#{c.encode(:xml => :attr)} d:title=#{title.encode(:xml => :attr)}/>"
    end.join('')
  end

  def drain_find_end(desc, pos)
    ['◆', '【'].map do |s|
      desc.index(s, pos)
    end.delete_if do |p|
      p.nil?
    end.first
  end

  def drain_attr_value(value)
    value.sub(/、$/, '').sub(/^([^】]+)】/, '')
  end

  def drain_attr(key, start, desc)
    p = desc.index(start)
    if p.nil?
      desc
    else
      q = drain_find_end(desc, p + start.size)
      if q.nil?
        @attrs[key] = drain_attr_value(desc[p..-1])
        desc.slice(0, [0, p - 1].max)
      else
        @attrs[key] = drain_attr_value(desc[p..q - 1])
        desc.slice(0, [0, p - 1].max) + desc.slice(q, desc.size - q)
      end
    end
  end

  def drain_pronounce(desc)
    drain_attr(:pronounce, '【発音】', desc)
  end

  def drain_pronounce_attn(desc)
    drain_attr(:pronounce_attn, '【発音！】', desc)
  end

  def drain_level(desc)
    drain_attr(:level, '【レベル】', desc)
  end

  def drain_kana(desc)
    drain_attr(:kana, '【＠】', desc)
  end

  def drain_part(desc)
    drain_attr(:part, '【分節】', desc)
  end

  def drain_conj(desc)
    drain_attr(:conj, '【変化】', desc)
  end

  def drain_exam(desc)
    desc.gsub('【大学入試】', '')
  end

  def render_break(desc)
    desc.gsub('◆', '<br/>').gsub('■・', '<br/>・')
  end

  def render_reference(desc)
    desc.gsub(/&lt;→(.+?)&gt;/) do |refs|
      '&lt;→' + $1.split(/\s:\s/).map do |r|
        "<a href='x-dictionary:r:#{identifier(r.gsub(/\[.+?\]|\(.+?\)|\{.+?\}/, ''))}'>#{r.strip}</a>"
      end.join(' ; ') + '&gt;'
    end
  end

  def render_url(desc)
    desc.gsub(URI::regexp(%w(http https))) do |l|
      "<a href='#{l}'>#{l}</a>"
    end
  end

  def render_ruby(desc)
    desc.gsub(/(\p{Han}+?)｛([\s\p{Katakana}\p{Hiragana}]+?)｝/) do |r|
      "<ruby><rb>#{$1}</rb><rp>(</rp><rt>#{$2}</rt><rp>)</rp></ruby>"
    end
  end

  def render_body
    [
        :drain_conj,
        :drain_part,
        :drain_kana,
        :drain_pronounce,
        :drain_pronounce_attn,
        :drain_level,
        :drain_exam,
        :render_url,
        :render_reference,
        :render_ruby,
        :render_break
    ].map do |m|
      method(m)
    end.inject(@desc.encode(:xml => :text)) do |d, m|
      m.call(d)
    end
  end

  def render_entry
    body = render_body
    if body.size > 0
      "<p>#{body}</p>"
    else
      ''
    end
  end
end

class EijiroDatabase
  def initialize(database_path)
    @database_path = database_path
  end

  def write
    SQLite3::Database.new(@database_path) do |db|
      db.execute('CREATE TABLE IF NOT EXISTS text (row TEXT, hash TEXT, word TEXT, klass TEXT, desc TEXT, PRIMARY KEY(row))')
      db.execute('CREATE INDEX IF NOT EXISTS texthash ON text (hash)')
      yield db
    end
  end

  def read
    SQLite3::Database.new(@database_path) do |db|
      yield db
    end
  end
end

class Loader < EijiroDatabase
  def initialize(database_path)
    super(database_path)
    @words = {}
    @count = 0
  end

  def render_line_opts(line, opts)
    if opts.has_key?(:ryaku)
      # Convert as PDIC format
      line.gsub(/\s:\s＝(.+?)([●◆])/) do 
        "\s:\s＝<→#$1>#$2"
      end
    else
      line
    end
  end

  def load_line(text_insert, line, opts)
    begin
      word = WordDefinition.from_line(render_line_opts(line, opts))
      word.serialize(text_insert, line)
      @count += 1
      if @count % 10000 == 0
        STDERR.printf '.'
      end
    rescue
      # ignore
    end
  end

  def load(opts)
    write do |db|
      WordDefinition.insert_statement(db) do |text_insert|
        STDIN.readlines.each do |line|
          load_line text_insert, line.encode('UTF-8', 'CP932'), opts
        end
      end
      num_rows = db.get_first_value('SELECT COUNT(*) FROM text')
      puts "#{num_rows} row(s) inserted."
    end
  end
end

class Exporter < EijiroDatabase
  def initialize(database_path)
    super(database_path)
  end

  def header(out_xml)
    out_xml.puts <<HEADER
<?xml version='1.0' encoding='UTF-8'?>
<d:dictionary xmlns='http://www.w3.org/1999/xhtml' xmlns:d='http://www.apple.com/DTDs/DictionaryService-1.0.rng'>
HEADER
  end

  def footer(out_xml)
    out_xml.puts '</d:dictionary>'
  end

  def export_for_hash(out_xml, select_stmt, hash)
    rows = select_stmt.execute 'hash' => hash
    words = rows.map do |r|
      WordDefinition.from_row r
    end.delete_if do |w|
      # Build fails if the keyword longer than 2047 bytes.
      # Build skips when keyword longer word.
      w.word.bytesize >= 320
    end

    if words.size > 0
      chunk = WordChunk.new(words)
      out_xml.puts chunk.render_chunk
    end
  end

  def export(output_path, opts = {})
    query_base = 'SELECT DISTINCT hash FROM text'
    hash_query = if opts.has_key?(:random)
                   query_base + " WHERE SUBSTR(hash, 1, 2) = '00'"
                 else
                   query_base
                 end

    open(output_path, 'w') do |out_xml|
      header(out_xml)
      read do |db|
        WordDefinition.select_statement(db) do |select|
          db.execute(hash_query) do |hash_row|
            export_for_hash(out_xml, select, hash_row[0])
          end
        end
      end
      footer(out_xml)
    end
  end
end

oper = {}
OptionParser.new do |opt|
  opt.banner = 'Usage: eijiro.rb [options]'
  opt.on('-dDATABASE', '--database=DATABASE', 'Database path') do |v|
    oper[:database] = v
  end
  opt.on('-l', '--load', 'Load Eijiro Text from STDIN into database') do |v|
    oper[:load] = v
  end
  opt.on('-r', '--ryaku', 'Load Ryakujiro Text') do |v|
    oper[:ryaku] = v
  end
  opt.on('-eXML', '--export=XML', 'Export as Dictionary XML') do |v|
    oper[:export] = v
  end
  opt.on('-s', '--random-sampling', 'Random sampling (1/256) on export') do |v|
    oper[:random] = v
  end
  opt.on('-h', '--help', 'Print this help') do
    puts opt
    exit
  end
end.parse!

unless oper.has_key?(:database)
  puts "Database path required."
  exit
end

if oper.has_key?(:load)
  loader = Loader.new(oper[:database])
  loader.load(oper)
end

if oper.has_key?(:export)
  exporter = Exporter.new(oper[:database])
  exporter.export(oper[:export], oper)
end
