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

# Data structures
# session[:lists] << { name: list_name, todos: [] }
# session[:lists][:todos] << {name: todo, completed: false}
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

    incomplete_lists.each { |list| yield list, lists.index(list) }
    complete_lists.each { |list| yield list, lists.index(list) }
  end

  def sort_todos(todos, &block)
    complete_todos, incomplete_todos = todos.partition { |todo| todo[:completed] }

    incomplete_todos.each { |todo| yield todo, todos.index(todo) }
    complete_todos.each { |todo| yield todo, todos.index(todo) }
  end

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

# Todo page, single list
get '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :single_list, layout: :layout
end

# Render the edit an existing todo list form
get '/lists/:list_id/edit' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  erb :edit_list, layout: :layout
end

# Edit an existing todo list name
post '/lists/:list_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  list_name = params[:list_name].strip

  error = error_for_list_name(list_name)
  if error
    session[:error] = error
    erb :edit_list, layout: :layout
  else
    @list[:name] = list_name
    session[:success] = 'The list name has been modified.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete an existing todo list
post '/lists/:list_id/destroy' do
  list_id = params[:list_id].to_i
  session[:lists].delete_at(list_id)
  session[:success] = 'The list name has been deleted.'
  redirect "/lists"
end

# Add todo items
post '/lists/:list_id/todos' do
  @list_id = params[:list_id].to_i
  todo = params[:todo].strip
  @list = session[:lists][@list_id]

  if !(1..100).cover? todo.size
    session[:error] = 'Todo must be between 1 and 100 characters.'
    erb :single_list, layout: :layout
  else
    @list[:todos] << {name: todo, completed: false}
    session[:success] = 'The todo item has been created.'
    redirect "/lists/#{@list_id}"
  end
end

# Delete an existing todo item within a todo list
post '/lists/:list_id/todos/:todo_id/destroy' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]
  todo_id = params[:todo_id].to_i
  todo_name = @list[:todos].delete_at(todo_id)
  session[:success] = "The todo item '#{todo_name[:name]}' has been deleted."
  redirect "/lists/#{@list_id}"
end

# Mark a todo item as done/undone
post '/lists/:list_id/todos/:todo_id' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  todo_id = params[:todo_id].to_i
  is_completed = params[:completed] == "true"
  @list[:todos][todo_id][:completed] = is_completed

  session[:success] = "The todo has been updated."
  redirect "/lists/#{@list_id}"
end

# Mark all todo items as done
post '/lists/:list_id/complete_all' do
  @list_id = params[:list_id].to_i
  @list = session[:lists][@list_id]

  @list[:todos].each { |todo| todo[:completed] = true }

  session[:success] = "All todos have been marked as done."
  redirect "/lists/#{@list_id}"
end