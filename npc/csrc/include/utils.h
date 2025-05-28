#ifndef __UTILS_H__
#define __UTILS_H__

#define BLUE_PRINT(...) \
	do { \
		printf("\033[34m"); \
		printf(__VA_ARGS__); \
		printf("\033[0m"); \
	} while (0)

#define log_write(...) \
	do { \
		extern FILE* log_fp; \
		if (log_fp != NULL) { \
			fprintf(log_fp, __VA_ARGS__); \
			fflush(log_fp); \
		} \
	} while (0)

#define Log(...) \
	do { \
		log_write(__VA_ARGS__); \
		BLUE_PRINT(__VA_ARGS__); \
	} while (0)

void init_log(const char *log_file);

#endif 
