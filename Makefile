start-server:
	bundle exec falcon serve -c config.ru --threaded

start-client:
	ruby client.rb