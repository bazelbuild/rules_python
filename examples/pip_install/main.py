import boto3
import tree_sitter

def the_dir():
    return dir(boto3)


if __name__ == "__main__":
    print(the_dir())
