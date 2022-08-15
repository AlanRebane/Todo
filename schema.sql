CREATE TABLE lists (
  id serial PRIMARY KEY,
  name text NOT NULL UNIQUE
);

CREATE TABLE todos (
  id serial PRIMARY KEY,
  name text NOT NULL,
  completed boolean DEFAULT false NOT NULL,
  list_id integer REFERENCES lists(id) NOT NULL
);