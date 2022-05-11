# frozen_string_literal: true

require 'sinatra'
require 'sinatra/reloader'
require 'tilt/erubis'
require "sinatra/content_for"

configure do
  enable :sessions
  set :session_secret, 'secret'
end

before do
  session[:lists] ||= []
end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = session[:lists]
  erb :lists, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif session[:lists].any? { |list| list[:name] == name }
    'List name must be unique.'
  end
end

# Create a new list
post '/lists' do
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :new_list, layout: :layout
  else
    session[:lists] << { name: list_name, todos: [] }
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Create a new todo item
post 'lists/:todo_id' do
end

# Todo page, single list
get '/lists/:todo_id' do
  @list = session[:lists][params[:todo_id].to_i]
  erb :single_list, layout: :layout
end

# Render the edit an existing todo list form
get '/lists/:todo_id/edit' do
  @list = session[:lists][params[:todo_id].to_i]
  erb :edit_list, layout: :layout
end

# Edit an existing todo list name
post '/lists/:todo_id' do
  todo_id = params[:todo_id].to_i
  @list = session[:lists][todo_id]
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list name has been modified.'
    redirect "/lists/#{todo_id}"
  end
end

# Delete an existing todo
post "/lists/:todo_id/destroy" do
  todo_id = params[:todo_id].to_i
  session[:lists].delete_at(todo_id)
  session[:success] = 'The list name has been deleted.'
  redirect "/lists"
end