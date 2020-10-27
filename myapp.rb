require "bundler/setup"
require 'sinatra'
require 'sinatra/reloader'
require 'pry'
#インストールしたActiveRecordを読み込めるようにする
require "sinatra/activerecord"
require 'bcrypt'
require 'rack-flash'
enable :sessions
use Rack::Flash

#movies
class Movie < ActiveRecord::Base
    #1対多
    has_many :reviews

    validates :name,presence: true
    validates :director, presence: true
    validates :summry, presence: true,length:{minimum: 10}
end

#reviews
class Review < ActiveRecord::Base
    #もしユーザーがなかったら
    belongs_to :movie, required: true
    belongs_to :user,  required: true

    validates :point, presence: true
    validates :comment, presence: true

    def user_name
        user.name
    end
end

#users
class User < ActiveRecord::Base
    has_many :reviews
    validates :name,presence: true, length:{maximum: 10}
    validates :email, presence: true, length:{maximum: 255},format:{with: /\A[\w+\-.]+@[a-z\d\-.]+\.[a-z]+\z/i}, uniqueness: { case_sensitive: false }
    #暗号化用の宣言（内部にてvalidatesしている）
    has_secure_password
end

#ユーザー登録画面
get '/users/new' do
    #もしログインしていなかったら一覧へリダイレクト
    redirect to('/movies') if !!session[:user_id]
    @user = User.new(user_params)
    erb :'users/new'
end

get('/signup') {redirect to :'users/new'}

#ユーザー登録処理
post '/users' do
    @user = User.create(user_params)
    #保存に失敗したらレンダーする
    return erb :'users/new' unless @user.save
    #ログイン状態にする
    session[:user_id] = @user.id
    redirect to('/movies')
end

#指定したデータベースと接続できるようにする
set :database, {adapter: "sqlite3", database: "sample_app.sqlite3"}

get '/' do
    erb :home
end

get '/hoge' do
    erb :hogedayo
end

#映画レビュー一覧
get '/movies' do
    @movies = Movie.all
    # @reviews = @movies.reviews
    erb :'movies/index'
end

#ユーザーの登録
post '/movies' do
    # binding.pry
    #フォームからの入力値をセットし保存
    @movie = Movie.new(movies_params)
    if @movie.save
        redirect to('/movies')
    else
        erb :'movies/new'
    end
end

#登録フォーム
get '/movies/new' do
    @movie = Movie.new(movies_params)
    erb :'movies/new'
end

#詳細ページ
get '/movies/:id' do
    @movie = Movie.find(params[:id])
    @reviews = @movie.reviews.includes(:user)
    erb :'movies/show'
end

#編集画面の表示
get '/movies/:id/edit' do
    @movie = Movie.find(params[:id])
    erb :'movies/edit'
end

#更新の実行
patch '/movies/:id' do
    # binding.pry
    @movie = Movie.find(params[:id])
    #更新に失敗した場合、レンダーする
    return erb :'movies/edit' unless @movie.update(movies_params)
    redirect to("/movies/#{@movie.id}")
end

#削除の実行
delete '/movies/:id' do
    #select movies.* from movies where movis.id = ? limit = ?;1件
    movie = Movie.find(params[:id])
    #delete from movies where movies.id = ?;
    movie.destroy
    redirect to("/movies")
end

#レビューの投稿画面
get '/movies/:movie_id/reviews/new' do
    # binding.pry
    #ログインしていなかったらログインページへリダイレクト
    return redirect to("/sessions/new") unless logged_in?
    movie = Movie.find(params[:movie_id])
    #空っぽのレビューを準備する(newしてるのと同じ)
    @review = movie.reviews.build
    #レンダーする
    erb :'movies/reviews/new'
end

#レビューの保存実行
post '/movies/:movie_id/reviews' do
    movie = Movie.find(params[:movie_id])
    @review = movie.reviews.build(review_params)
    @review.user_id = current_user.id
    #レビューの保存に失敗したらレンダーする
    return erb :'movies/reviews/new' unless @review.save
    redirect to("/movies/#{@review.movie_id}")
end

#ログインしているか
helpers do
    def logged_in?
        #セッションにユーザーIDが格納されているか
        !!session[:user_id]
    end
end

get '/movies/:movie_id/reviews/new' do
    return redirect to("/sessions/new") unless logged_in?
    movie = Movie.find(params[:movie_id])
    @review = movie.reviews.build
    erb :'movies/reviews/new'
end

#ログインページの表示
get '/sessions/new' do
    @user = User.new(user_params)
    return redirect to('/movies/') if logged_in?
    erb :'sessions/new'
end

get('/signin') {redirect :'sessions/new'}

#ログイン
post '/sessions' do
    @user = User.find_by(email: params[:email])

    #パスワードの暗号化 & 照合
    unless @user&.authenticate(params[:password])
        @user = User.new(user_params)
        flash.now[:error] = "IDかパスワードが間違っているか、会員ではありません。"
        return erb :'sessions/new'
    end

    #セッション情報の取得
    session[:user_id] = @user.id
    redirect to('/movies')
end

#ログアウト（セッションの初期化）
delete '/sessions' do
    session.clear
    redirect to('/movies')
end

#許可するパラメータを設定
def movies_params
    params.slice(:name, :director, :summry)
end

def review_params
    params.slice(:movie_id, :point, :comment)
end

def user_params
    params.slice(:name, :email, :password)
end

def current_user
    #ログインしているか（返り値：nil）
    return unless session[:user_id]
    #もしカレントユーザーが存在していれば@current_userを返し、しなければDBより取得し、格納
    #@current_user = @current_user || User.find(session[:user_id])の略
    @current_user ||= User.find(session[:user_id])
end
