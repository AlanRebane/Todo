# frozen_string_literal: true

require 'sinatra'
require 'tilt/erubis'
require "sinatra/content_for"
require_relative "database_persistence"

configure do
  enable :sessions
  set :session_secret, 'secret'
  set :erb, :escape_html => true
end

configure(:development) do
  require 'sinatra/reloader'
  also_reload "database_persistence.rb"
end

before do
  @storage = DatabasePersistence.new(logger)
end

helpers do
  def count_incomplete_todos(list)
    count = 0
    list[:todos].each { |todo| count += 1 if todo[:completed] == false }
    count
  end

  def count_all_todos(list)
    list[:todos].size
  end

  def all_todos_completed?(list)
    count_incomplete_todos(list) == 0 && count_all_todos(list) > 0
  end

  def sort_lists(lists, &block)
    complete_lists, incomplete_lists = lists.partition { |list|  all_todos_completed?(list) }

    incomplete_lists.each(&block)
    complete_lists.each(&block)
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end
end

def load_list(id)
  list = @storage.find_list(id)
  
  return list if list

  session[:error] = "The specified list was not found."
  redirect "/lists"
end

# not_found do
#   redirect '/'
# end

get '/' do
  redirect '/lists'
end

# View list of lists
get '/lists' do
  @lists = @storage.all_lists
  erb :lists, layout: :layout
end

# Return an error message if the name is invalid. Return nil if name is valid.
def error_for_list_name(name)
  if !(1..100).cover? name.size
    'List name must be between 1 and 100 characters.'
  elsif @storage.all_lists.any? { |list| list[:name] == name }
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
    @storage.create_new_list(list_name)
    session[:success] = 'The list has been created.'
    redirect '/lists'
  end
end

# Render the new list form
get '/lists/new' do
  erb :new_list, layout: :layout
end

# Todo page, single list
get '/lists/:list_id' do
  id = params[:list_id].to_i
  @list = load_list(id)
  @list_name = @list[:name]
  @list_id = @list[:id]
  @todos = @list[:todos]

  erb :single_list, layout: :layout
end

# Render the edit an existing todo list form
get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  erb :edit_list, layout: :layout
end

# Edit an existing todo list name
post '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @storage.update_list_name(@list_id, list_name)
    session[:success] = ('The list name has been modified.')
    redirect "/lists/#{@list_id}"
  end
end

# Delete an existing todo list
post '/lists/:list_id/destroy' do
  list_id = params[:list_id].to_i

  @storage.delete_list(list_id)
  
  session[:success] = "The list has been deleted."
  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    "/lists"
  else
    session[:success] = 'The list name has been deleted.'
    redirect "/lists"
  end
end

# Add todo items
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  text = params[:todo].strip

  if !(1..100).cover? text.size
    session[:error] = 'Todo must be between 1 and 100 characters.'
    erb :single_list, layout: :layout
  else

    @storage.create_new_todo(@list_id, text)

    session[:success] = 'The todo item has been created.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete an existing todo item within a todo list
post '/lists/:list_id/todos/:todo_id/destroy' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @todo_id = params[:todo_id].to_i
  @storage.delete_todo_from_list(@list_id, @todo_id)

  if env["HTTP_X_REQUESTED_WITH"] == "XMLHttpRequest"
    status 204
  else
    session[:success] = "The todo item has been deleted."
    redirect "/lists/#{@list_id}"
  end
end

# Mark a todo item as done/undone
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"

  @storage.update_todo_status(@list_id, todo_id, is_completed)

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todo items as done
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = load_list(@list_id)

  @storage.mark_all_todos_complete(@list_id)

  session[:success] = "All todos have been marked as done."
  redirect "/lists/#{@list_id}"
end