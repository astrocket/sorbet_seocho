# Sorbet for 서초루비

## Sorbet 소개

> 루비에서 타입을 선언 하기 쉽도록 도와주는 라이브러리
>
> 페이먼트 회사인 Stripe 에서 개발시작 (Coinbase / Shopify 등 회사들이 함께 개발중)

### Stripe의 Sorbet 소개 @ RubyKaigi2019

```text
Stripe 백엔드 코드 대부분이 ruby 로 개발(but rails X)

코드 베이스가 거대한 monolith에 가까운 구조.
-> 계속해서 기존 코드에 추가하는 방식

2017년 10월 부터 개발 시작 (2년 가까이 개발진행)
2019년 루비 카이기에서 오픈소스로 공개 밝히고 공개됨

루비 특성상 코드가 런타임에서 돌아가기전에 알 수 없는 에러들을 올리기전에 찾을 수 없을까? 에서 출발
루비 코어팀과 3.0 버전의 타입 기능을 위해 협업중 -> 루비 계속 할거면 언젠가는 타입 해야함
```



## Sorbet 시작하기

```ruby
gem 'sorbet', :group => :development
gem 'sorbet-runtime'
```

설치하면… 아래가 쭉 생김

```ruby
➜ bundle install
➜ bundle exec srb init # rbi 파일들이 막 추가됨

sorbet/
│ # Default options to passed to sorbet on every run
├── config
└── rbi/
    │ # 커뮤니티에서 올린 type definition 들
    ├── sorbet-typed/
    │ # type definition 이 없는 gem 들을 로드해서 메서드명, params 갯수, 상수 등을 최대한 가져와서 만든것
    ├── gems/
    │ # MetaProgramming 으로 만들어진 method 들이 여기에 담김.
    ├── hidden-definitions/
    │ # Constants which were still missing
    └── todo.rbi
```

아래 커맨드로 타입 체크

```bash
➜ srb tc
No errors! Great job.
```





## Sorbet 작동원리

1. Static Check

   - 파일 단위로 타입을 체크 `srb` 로 실행 (파일내에서 -> 특정 메소드 / Argument / 메소드 호출의 타입을 체크해준다.)
   - `ignore` / `false` / `true` / `strict` / `strong` 5종류로 타입 체크 정도를 사전 정의
   - `ignore` : 아예 무시
   - `false` : 기본적인 syntax 에러
   - `true` : + no method 에러 체크, 타입 mismatch 체크
   - `strict` : + 모든 메서드에 `signature` 가 정의 / 사용되는 모든 변수가 `type` 갖도록
   - `strong` : + `T.untyped` (타입이 없는 타입)도 허용하지 않는 단계. rbi 파일 이외에 잘 쓸일은 없음
   - `#typed: false` 이더라도 `#typed: true` 인 파일이 부르면 타입 체크가 이루어짐

   ```ruby
   # typed: true
   extend T::Sig
   
   sig {params(env: T::Hash[Symbol, T.untyped], key: Symbol).void}
   def log_env(env, key)
     puts "LOG: #{key} => #{env[key]}"
   end
   
   log_env({timeout_len: 2000, user: 'jez'}, :user)  # ok
   ```

2. Dynamic Check

   -  `sig` 를 정의해주면 이게 runtime 에서 원 메서드를 덮어쓰며 아래같은 동작을 하게 해준다.
     1. 런타임 상에서 주입된 argument 가 타입이 일치하는지 확인
     2. 원 메서드 호출 시도
     3. 리턴타입이 타입과 일치하는지 확인
     4. 리턴된 실제 결과를 리턴
   - 테스트 코드를 돌리는거 자체가 타입 테스팅 까지 하는게 되어서 좋음.
   - 런타임 체크를 끄거나, 단순 로그성으로 전환할 수 있음

   ```ruby
   class Example
     extend T::Sig
   
     sig {params(x: Integer).returns(String)}
     def self.main(x)
       "Passed: #{x.to_s}"
     end
   end
   
   Example.main([]) # passing an Array!
   
   ❯ ruby example.rb
   ...
   Parameter 'x': Expected type Integer, got type Array with unprintable value (TypeError)
   Caller: example.rb:11
   Definition: example.rb:6
   ...
   ```

   



## Sorbet 살펴보기

```ruby
#typed: true

require 'sorbet-runtime'

class Main
  # 'sig' annotation 을 위해서 추가해주는 모듈
  extend T::Sig
  
  # input / output 모두 타입체크
  sig { params(x: String).returns(Integer) }
  def self.main(x)
    x.length
  end
  
  # output 만 타입체크
  sig { returns(Integer) }
  def no_params
    42
  end
end
```





## Sorbet 중요개념

### Signature

```ruby
sig {params(x: SomeType, y: SomeOtherType).returns(MyReturnType)}

sig do
  params(
    x: SomeType,
    y: SomeOtherType,
  )
  .returns(MyReturnType)
end

sig {returns(MyReturnType)}

sig {void} # puts "Hello" 처럼 리턴이 없는경우
```

### Type Annotation

```ruby
# constant
NAMES = T.let(["Nelson", "Dmitry", "Paul"], T::Array[String])

# instance variable
@foo = T.let(0, Integer
  
# class variable
@@llamas = T.let([], T::Array[Llama])

# method
sig {params(x: Integer, y: Integer).void}
def initialize(x, y); end
```

```ruby
# 아직은 변수끼리 타입 공유가 되지 않음. 변수 재할당시 T.untyped 로 복사됨. 재선언 해야함
class Foo
  sig {params(x: Integer, y: Integer).void}
  def initialize(x, y)
    @x = x
    @y = T.let(y, Integer)

    T.reveal_type(@x)  # T.untyped ??
    T.reveal_type(@y)  # Integer
  end
end
```

### Type Assertion

```ruby
# T.let
y = T.let(10, String) # error: Argument does not have asserted type String 

# T.cast 뭐가 들어오든 A 클래스로 취급해서 정적분석. b 가 들어와서 B 메서드를 호출하면 에러
T.cast(a_or_b, A).foo # A 클래스가 foo 메서드를 가지고 있어야만 Static type check 를 통과
T.cast(a_or_b, A).bad_method # srb 실행시 missing method 에러 유발

# T.must : 변수가 nil 이면 에러 &. 와 유사함
y = T.must(nil) # 에러

# T.assert_type! : 특정 타입 강제 (타입이 없는 것과 같은 T.untyped 의 경우에는 에러)
sig {params(x: T.untyped).void}
def foo(x)
  T.assert_type!(x, String) # error here
end
```

### Class Types

```ruby
String
Symbol
Integer
Float
NilClass
T::Boolean # (there is no `Boolean` class in Ruby)
Hash / T::Hash # Hash == T::Hash[T.untyped, T.untyped]
Array / T::Array # Array == T::Array[T.untyped]
T.untyped # Type 이 할당되지 않은 모든것의 기본 타입
CustomClass # 클래스명도 타입으로 간주됨
부모자식 -> 부모로 선언시 자식 클래스 인스턴스도 허용
Module -> ModuleName 로 sig 선언시 해당 ModuleName 을 include 하는 클래스면 허용
```

### Nil

```ruby
sig {params(x: T.nilable(String)).void} # input이 nil 이여도 상관없는 경우
def foo(x)
end

T.must(val) # val 은 nil 이 아니라고 강제해서 분석 Static Check 에서 nil method missing 에러 방지
```

### 기타

```ruby
T.any(SomeType, SomeOtherType, ...) # ~~ 중 하나
```

```ruby
# typed: true
class A; end
A.new.foo   # Method foo does not exist on A
T.let(A.new, T.untyped).foo  # No errors! Great job.
```

```ruby
A = T.type_alias(Integer) # A 가 Integer 타입처럼 동작
```



## Sorbet-Rails

`https://github.com/chanzuckerberg/sorbet-rails` 

Model / Routes 에 필요한 rbi 자동생성 해주는 라이브러리 (발표준비하는 과정에 Helper 도 추가됨)

```ruby
rake rails_rbi:models
```

Task 실행 해주면 모델 훑으면서 rbi 파일들 만들어줌 어떤것들을 해주는지 살펴보면 아래와 같음.

- 레코드 칼럼 호출하는 메서드

  ```ruby
  # Event.last.created_at
  module Event::InstanceMethods
    extend T::Sig
  
    sig { returns(DateTime) }
    def created_at(); end
  
    sig { params(value: DateTime).void }
    def created_at=(value); end
  
    sig { params(args: T.untyped).returns(T::Boolean) }
    def created_at?(*args); end
  end
  ```

- 모델관계에서 만들어지는 메서드들

  ```ruby
  # Event.last.event_items
  class Event
    extend T::Sig
  
    sig { returns(::EventItem::ActiveRecord_Associations_CollectionProxy) }
    def event_items(); end
    
    
    sig { params(value: T.any(T::Array[::EventItem], ::EventItem::ActiveRecord_Associations_CollectionProxy)).void }
    def event_items=(value); end
  end
  ```

- AASM 에서 동적으로 생성해주는 메서드들

  ```ruby
  #  enum fare_type: {
  #      time: 'time',
  #      distance: 'distance'
  #  }
  
  module Reservation::InstanceMethods
    extend T::Sig
      sig { void }
      def tel!(); end
  
      sig { returns(T::Boolean) }
      def tel?(); end
  
      sig { void }
      def time!(); end
  
      sig { returns(T::Boolean) }
      def time?(); end
  	end
  end
  ```

- 데이터 베이스 연관 액션들

  ```ruby
  # Event.all
  module Event::ModelRelationShared
    extend T::Sig
  
    sig { returns(Event::ActiveRecord_Relation) }
    def all(); end
  
    sig { params(block: T.nilable(T.proc.void)).returns(Event::ActiveRecord_Relation) }
    def unscoped(&block); end
  
    sig { params(args: T.untyped).returns(Event::ActiveRecord_Relation) }
    def running(*args); end
  
    sig { params(args: T.untyped, block: T.nilable(T.proc.void)).returns(Event::ActiveRecord_Relation) }
    def select(*args, &block); end
  end
  ```

- 모델에 개발자가 선언한 메서들은 자동 정의 되지는 않음.



## Rails 실습

`rails new sorbet_seocho` 로 Rails 프로젝트 생성 후 아래 Gem 추가

```ruby
gem 'sorbet', :group => :development
gem 'sorbet-runtime'
```

`bundle install` 후 레거시 환경 가정을 위해서 모델 및 메서드 몇개 추가

```bash
➜ rails db:create
➜ rails g model Booker name phone
➜ rails g model Reservation booker:references checkin:datetime
➜ rails db:migrate
➜ rails g controller Reservations index
```

`rails c` 실행 후 데모용 레코드 두개 추가

```ruby
➜ Booker.create(name: "Astro", phone: "01011111111")
➜ Booker.first.reservations.create(checkin: Time.now + 5.days)
```

`app/models/booker.rb` 파일에 relation 추가

```ruby
class Booker < ApplicationRecord
  has_many :reservations
end
```

`app/models/reservation.rb` 파일에 메서드 두개 추가

```ruby
class Reservation < ApplicationRecord

  belongs_to :booker

  def booker_name_i18n(country_code)
    translation_api(booker.name, country_code)
  end

  private

  # 번역 API 라고 가정
  def translation_api(target, country_code)
    "아스트로(#{target})" if country_code == :ko
  end
end
```

`app/controllers/reservations_controller.rb` 에 Reservation 하나 꺼내서 Booker 의 이름을 다국어로 꺼내는 함수 실행하는 코드 추가.

```ruby
class ReservationsController < ApplicationController
  def index
    reservation = Reservation.first
    name = reservation.booker_name_i18n(:ko)

    render json: name
  end
end
```

레거시 어플리케이션 환경이 세팅 되었다고 가정하고 sorbet 설치

`bundle exec srb init` 실행

Rails 특수한 rbi 생성에 도움을 받기 위해서 `sorbet-rails` 설치

```ruby
gem 'sorbet-rails'
```

아래 rake task 를 실행하면 model 에 관련된 기본적인 relation, aasm, active_record method 같은 것들의 타입 인터페이스를 만들어줍니다. 쉽게 생각하면 레일즈 및 라이브러리가 자동으로 해주는 것들의 타입선언 스캐폴드라고 보면됩니다. (모델에 직접 정의한 `booker_name_i18n` 에 대해서는 타입선언이 자동작성되지 않음)

```bash
rake rails_rbi:models
```

```ruby
# 자동으로 생성된 active_record / relation 관련 메서드들과 타입선언 샘플
...
sig { returns(T.nilable(DateTime)) }
def checkin(); end
...
sig { returns(::Booker) }
def booker(); end
...
```

그 다음에 `booker_name_i18n` 먼저 선언한 이 메서드의 input 인 `country_code` 의 타입을 `Symbol` 로 강제하기 위해서 sorbet 경로 아래에 생성된 `reservations.rbi ` 에 아래처럼 코드를 추가해 줍니다.

```ruby
...
  
class Reservation
  extend T::Sig
...
  sig { params(country_code: Symbol).returns(String) }
  def booker_name_i18n(country_code); end
end
...
```

이 상태에서 `srb tc` 로 타입체크를 해주면 `reservation.name_i18n` 에서 `reservation` 이 `nil` 일 때 발생가능한 에러를 detect 하게 됩니다. `reservation` 이 안전하다고 가정하고 `T.must` 를 사용하거나  `&.` 로 nil safety 를 보장시켜주도록 코드를 수정합니다.

타 개발자에 의해서 `:ko` 로 들어오던 국가코드가 `"ko"` 로 들어와서 번역 API 와의 호환성이 문제가 생기는 상황을 가정해보고 `:ko` 대신 `"ko"` 를 넣어보고 `srb tc` 로 정적분석을 해주면 우리가 원하던 타입에러가 발생합니다.



## Q/A 시간

## References
[sorbet](https://sorbet.org/)
[sorbet-rails](https://github.com/chanzuckerberg/sorbet-rails)